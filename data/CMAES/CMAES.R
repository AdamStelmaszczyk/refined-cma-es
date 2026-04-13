ipop_stop <- function(
    all_conditions, bestVal.log, lambda, xmean, arfitness, B, D, sigma, pc,
    TolFun = 1e-12,
    TolX_factor = 1e-12,
    CondCov = 1e14
) {
  TolX <- TolX_factor * sigma
  if (all(D < TolX) && all(sigma * pc < TolX)) {
    return("tolx")
  }

  if (!all_conditions) {
    return(NULL)
  }

  N <- length(pc)
  hist_len <- 10 + ceiling(30 * N / lambda)
  if (nrow(bestVal.log) >= hist_len) {
    recent <- tail(bestVal.log[,1], hist_len)
    r1 <- max(recent) - min(recent)
    r2 <- max(c(recent, arfitness)) - min(c(recent, arfitness))
    if (r1 == 0 || r2 < TolFun)
      return("equalfunvalhist")
  }

  for (i in seq_len(N)) {
    dx <- 0.1 * sigma * B[, i] * D[i, i]
    if (!all(xmean == xmean + dx)) {
      break
    }
    if (i == N) {
      return("noeffectaxis")
    }
  }

  for (i in seq_len(N)) {
    dx <- 0.2 * sigma
    x2 <- xmean
    x2[i] <- x2[i] + dx
    if (all(xmean == x2)) {
      return("noeffectcoord")
    }
  }

  d <- diag(D)
  if ((max(d) / min(d))^2 > CondCov) {
    return("conditioncov")
  }

  return(NULL)
}

best_of_random <- function(N, fn, lower, upper, n_samples = 100) {
  best_val <- Inf
  best_par <- NULL
  for (i in 1:n_samples) {
    x <- runif(N, lower, upper)
    v <- fn(x)
    if (v < best_val) {
      best_val <- v
      best_par <- x
    }
  }
  return(best_par)
}


cmaes <- function(par, fn, ..., lower, upper, control=list()) {
  norm <- function(x)
    drop(sqrt(crossprod(x)))

  controlParam <- function(name, default) {
    v <- control[[name]]
    if (is.null(v))
      return (default)
    else
      return (v)
  }

  ## Inital solution:
  presamples <- controlParam("presamples", 1)

  N <- length(par)
  xmean <- best_of_random(N, fn, lower, upper, n_samples = presamples)

  ## Box constraints:
  if (missing(lower))
    lower <- rep(-Inf, N)
  else if (length(lower) == 1)
    lower <- rep(lower, N)

  if (missing(upper))
    upper <- rep(Inf, N)
  else if (length(upper) == 1)
    upper <- rep(upper, N)

  ## Parameters:
  trace       <- controlParam("trace", FALSE)
  fnscale     <- controlParam("fnscale", 1)
  stopfitness <- controlParam("stopfitness", -Inf)
  budget      <- controlParam("budget", 10000*N )                     ## The maximum number of fitness function calls
  sigma       <- controlParam("sigma", 0.5)
  # sigma       <- controlParam("sigma", 7)
  sc_tolx     <- controlParam("stop.tolx", 1e-12)
  keep.best   <- controlParam("keep.best", TRUE)
  vectorized  <- controlParam("vectorized", FALSE)
  flat_escape <- controlParam("flat_escape", TRUE)
  midpoint_freq <- controlParam("midpoint_freq", 0)
  ipop_restarts <- controlParam("ipop_restarts", 0)
  boundary_handling <- match.arg(
    controlParam("boundary_handling", "penalty"),
    c("penalty", "resample")
  )
  local_optimizer <- controlParam("local_optimizer", FALSE)
  hsig_type <- match.arg(
    controlParam("hsig_type", "default"),
    c("default", "no_hsig", "hsig_on")
  )

  ## Logging options:
  log.all    <- controlParam("diag", FALSE)
  log.sigma  <- controlParam("diag.sigma", log.all)
  log.eigen  <- controlParam("diag.eigen", log.all)
  log.value  <- controlParam("diag.value", log.all)
  log.pop    <- controlParam("diag.pop", log.all)
  log.bestVal<- controlParam("diag.bestVal", log.all)

  ## Strategy parameter settings
  lambda      <- controlParam("lambda", 4+floor(3*log(N)))
  # lambda      <- controlParam("lambda", 4*N)
  maxiter     <- controlParam("maxit", round(budget/lambda))
  mu          <- controlParam("mu", floor(lambda/2))
  weights     <- controlParam("weights", log(mu+1) - log(1:mu))
  weights     <- weights/sum(weights)
  mueff       <- controlParam("mueff", sum(weights)^2/sum(weights^2))
  cc          <- controlParam("ccum", 4/(N+4))
  cs          <- controlParam("cs", (mueff+2)/(N+mueff+3))
  mucov       <- controlParam("ccov.mu", mueff)
  ccov        <- controlParam("ccov.1",
                              (1/mucov) * 2/(N+1.4)^2
                              + (1-1/mucov) * ((2*mucov-1)/((N+2)^2+2*mucov)))
  damps       <- controlParam("damps",
                              1 + 2*max(0, sqrt((mueff-1)/(N+1))-1) + cs)

  ## Safety checks:
  stopifnot(length(upper) == N)
  stopifnot(length(lower) == N)
  stopifnot(all(lower < upper))
  stopifnot(length(sigma) == 1)

  ## Bookkeeping variables for the best solution found so far:
  best.fit <- Inf
  best.par <- NULL

  ## Preallocate logging structures:
  if (log.sigma)
    sigma.log <- numeric(maxiter)
  if (log.eigen)
    eigen.log <- matrix(0, nrow=maxiter, ncol=N)
  if (log.value)
    value.log <- matrix(0, nrow=maxiter, ncol=mu)
  if (log.pop)
    pop.log <- array(0, c(N, mu, maxiter))
  if(log.bestVal)
    bestVal.log <-  matrix(0, nrow=0, ncol=1)

  ## Initialize dynamic (internal) strategy parameters and constants
  pc <- rep(0.0, N)
  ps <- rep(0.0, N)
  B <- diag(N)
  D <- diag(N)
  BD <- B %*% D
  C <- BD %*% t(BD)

  chiN <- sqrt(N) * (1-1/(4*N)+1/(21*N^2))

  iter <- 0L      ## Number of iterations
  counteval <- presamples ## Number of function evaluations
  restarts <- 0
  cviol <- 0L     ## Number of constraint violations
  msg <- NULL     ## Reason for terminating
  nm <- names(par) ## Names of parameters

  ## Preallocate work arrays:
  arx <-  replicate(lambda, runif(N,lower,upper))
  arfitness <- apply(arx, 2, function(x) fn(x, ...) * fnscale)
  counteval <- counteval + lambda
  while (counteval < budget) {
    iter <- iter + 1L

    if (!keep.best) {
      best.fit <- Inf
      best.par <- NULL
    }
    if (log.sigma)
      sigma.log[iter] <- sigma

    if (log.bestVal)
      bestVal.log <- rbind(bestVal.log,min(suppressWarnings(min(bestVal.log)), min(arfitness)))

    ## Generate new population:
    arz <- matrix(rnorm(N*lambda), ncol=lambda)
    arx <- xmean + sigma * (BD %*% arz)

    if (boundary_handling == "penalty") {
      vx <- pmin(pmax(arx, lower), upper)
      if (!is.null(nm))
        rownames(vx) <- nm
      pen <- 1 + colSums((arx - vx)^2)
      pen[!is.finite(pen)] <- .Machine$double.xmax / 2
      cviol <- cviol + sum(pen > 1)
    } else {
      vx <- arx
      pen <- 1
    }

    if (vectorized) {
      y <- fn(vx, ...) * fnscale
    } else {
      y <- apply(vx, 2, function(x) fn(x, ...) * fnscale)
    }
    counteval <- counteval + lambda

    arfitness <- y * pen

    ## Order fitness:
    arindex <- order(arfitness)
    arfitness <- arfitness[arindex]

    aripop <- arindex[1:mu]
    selx <- arx[,aripop]
    xmean <- drop(selx %*% weights)
    selz <- arz[,aripop]
    zmean <- drop(selz %*% weights)

    if (boundary_handling == "resample") {
      for (i in seq_len(mu)) {
        if (any(arx[,i] < lower | arx[,i] > upper)) {
          attempts <- 0
          repeat {
            z <- rnorm(N)
            x <- drop(xmean + sigma * (BD %*% z))
            attempts <- attempts + 1
            if (all(x >= lower & x <= upper) || attempts >= 100) {
              range <- upper - lower
              x <- lower + abs((x - lower) %% (2 * range) - range) # mirror
              arx[,i] <- x
              arz[,i] <- z
              arfitness[i] <- fn(x, ...) * fnscale
              counteval <- counteval + 1L
              break
            }
          }
        }
      }
    }

    valid <- pen <= 1
    if (any(valid)) {
      wb <- which.min(y[valid])
      if (y[valid][wb] < best.fit) {
        best.fit <- y[valid][wb]
        best.par <- arx[,valid,drop=FALSE][,wb]
      }
    }

    ## Midpoint evaluation
    if (midpoint_freq > 0 && iter %% midpoint_freq == 0) {
      fval_mid <- fn(xmean, ...) * fnscale
      counteval <- counteval + 1L
      if (fval_mid < best.fit) {
        best.fit <- fval_mid
        best.par <- xmean
        if (trace)
          message(sprintf("Midpoint is new best: %f at iteration %i", best.fit * fnscale, iter))
      }
      if (log.value) value.log[iter, 1] <- fval_mid
    }

    ## Save selected x value:
    if (log.pop) pop.log[,,iter] <- selx
    if (log.value) value.log[iter,] <- arfitness[aripop]

    ## Cumulation: Update evolutionary paths
    ps <- (1-cs)*ps + sqrt(cs*(2-cs)*mueff) * (B %*% zmean)
    hsig <- drop((norm(ps)/sqrt(1-(1-cs)^(2*counteval/lambda))/chiN) < (1.4 + 2/(N+1)))
    if (hsig_type == "no_hsig")
      hsig <- 0
    if (hsig_type == "hsig_on")
      hsig <- 1
    pc <- (1-cc)*pc + hsig * sqrt(cc*(2-cc)*mueff) * drop(BD %*% zmean)

    ## Adapt Covariance Matrix:
    BDz <- BD %*% selz
    if (hsig_type == "no_hsig" || hsig_type == "hsig_on")
      hsig <- 1
    C <- (1-ccov) * C + ccov * (1/mucov) *
      (pc %o% pc + (1-hsig) * cc*(2-cc) * C) +
      ccov * (1-1/mucov) * BDz %*% diag(weights) %*% t(BDz)

    ## Adapt step size sigma:
    sigma <- sigma * exp((norm(ps)/chiN - 1)*cs/damps)

    e <- eigen(C, symmetric=TRUE)
    eE <- eigen(cov(t(arx)))
    if (log.eigen)
      eigen.log[iter,] <- rev(sort(eE$values))

    if (!all(e$values >= sqrt(.Machine$double.eps) * abs(e$values[1]))) {
      msg <- "Covariance matrix 'C' is numerically not positive definite."
      break
    }

    B <- e$vectors
    D <- diag(sqrt(e$values), length(e$values))
    BD <- B %*% D

    ## break if fit:
    if (arfitness[1] <= stopfitness * fnscale) {
      msg <- "Stop fitness reached."
      break
    }

    stop_reason <- ipop_stop(
      all_conditions = restarts < ipop_restarts,
      bestVal.log = bestVal.log,
      lambda = lambda,
      xmean = xmean,
      arfitness = arfitness,
      B = B,
      D = D,
      sigma = sigma,
      pc = pc,
      TolX_factor = sc_tolx
    )

    if (!is.null(stop_reason)) {
      if (restarts < ipop_restarts) {
        restarts <- restarts + 1

        lambda <- lambda * 2
        mu <- floor(lambda / 2)
        weights <- log(mu + 1) - log(1:mu)
        weights <- weights / sum(weights)
        mueff <- sum(weights)^2 / sum(weights^2)

        cs          <- controlParam("cs", (mueff+2)/(N+mueff+3))
        mucov       <- controlParam("ccov.mu", mueff)
        ccov        <- controlParam("ccov.1",
                                    (1/mucov) * 2/(N+1.4)^2
                                    + (1-1/mucov) * ((2*mucov-1)/((N+2)^2+2*mucov)))
        damps       <- controlParam("damps",
                                    1 + 2*max(0, sqrt((mueff-1)/(N+1))-1) + cs)

        xmean <- runif(N, lower, upper)
        sigma <- controlParam("sigma", 0.5)

        pc <- rep(0.0, N)
        ps <- rep(0.0, N)
        B <- diag(N)
        D <- diag(N)
        BD <- B %*% D
        C <- BD %*% t(BD)

        if (trace)
          message(sprintf("IPOP restart (%s), lambda = %i", stop_reason, lambda))

        next
      } else {
        if (stop_reason == "tolx") {
          msg <- "All standard deviations smaller than tolerance."
          break
        }
      }
    }

    ## Escape from flat-land:
    if (flat_escape && arfitness[1] == arfitness[min(1+floor(lambda/2), 2+ceiling(lambda/4))]) {
      sigma <- sigma * exp(0.2+cs/damps);
      if (trace)
        message("Flat fitness function. Increasing sigma.")
    }
    if (trace)
      message(sprintf("Iteration %i of %i: current fitness %f",
                      iter, maxiter, arfitness[1] * fnscale))
  }
  cnt <- c(`function`=as.integer(counteval), gradient=NA)

  log <- list()
  ## Subset lognostic data to only include those iterations which
  ## where actually performed.
  if (log.value) log$value <- value.log[1:iter,]
  if (log.sigma) log$sigma <- sigma.log[1:iter]
  if (log.eigen) log$eigen <- eigen.log[1:iter,]
  if (log.pop)   log$pop   <- pop.log[,,1:iter]
  if (log.bestVal) log$bestVal <- bestVal.log

  ## Drop names from value object
  names(best.fit) <- NULL
  res <- list(par=best.par,
              value=best.fit / fnscale,
              counts=cnt,
              convergence=ifelse(iter >= maxiter, 1L, 0L),
              message=msg,
              constr.violations=cviol,
              restarts=restarts,
              diagnostic=log
  )
  class(res) <- "cma_es.result"

  if (local_optimizer) {
    best_local_val <- Inf
    best_local_par <- res$par

    fn_wrapped <- function(x) {
      if (counteval >= budget)
        return(best_local_val + 1e100)

      counteval <<- counteval + 1L
      val <- fn(x, ...) * fnscale

      if (val < best_local_val) {
        best_local_val <<- val
        best_local_par <<- x
      }
      val
    }

    if (counteval < budget) {
      res_local <- optim(
        par = res$par,
        fn = fn_wrapped,
        method = "L-BFGS-B",
        lower = lower,
        upper = upper,
        control = list(
          factr = 0,
          pgtol = 0
        )
      )

      if (best_local_val < res$value * fnscale) {
        res$par <- best_local_par
        res$value <- best_local_val / fnscale
        res$message <- "CMA-ES + L-BFGS-B"
      }
    }
  }

  return(res)
}
