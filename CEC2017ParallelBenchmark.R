RUNS <- 25

args <- commandArgs(trailingOnly = TRUE)
ALG_ID <- args[1]
f_from <- if (length(args) >= 2) as.numeric(args[2]) else 1
f_to <- if (length(args) >= 3) as.numeric(args[3]) else 29
DIM <- if (length(args) >= 4) as.numeric(args[4]) else 30

benchmarkParallel <- function() {
  suppressMessages(library(foreach))
  suppressMessages(library(doParallel))

  start.time  <- Sys.time()

  # Minimal fitness values for each problem
  scores <- seq(from = 100, to = 3000, by=100)

  # Calculate the number of cores
  no_cores <- detectCores() - 1

  # Initiate cluster
  registerDoParallel(no_cores)

  cat("Problem(N=Dim D=Problem),Median,Best,Worst,Mean,Sd,Restarts\n")

  # For each dimension
  for (d in c(DIM)) {
    # Compute problems in parallel
    results = foreach(n = f_from:f_to,
                      .combine = c,
                      .export = c("scores", "d")) %dopar% {
      source('CMAES.R')
      library(cec2017)
      resultVector <- c()
			restarts <- c()
			informMatrix <- matrix(0, nrow = 1001, ncol = RUNS)
      for(i in 1:RUNS) {
			  result <- tryCatch({
				  cmaes(
						runif(d, -100, 100),
						fn = function(x) {
						  # cec17 without f2
						  if (n == 1) {
						    cec2017(1, x)
						  } else {
						    cec2017(n + 1, x)
						  }
						},
						lower = -100,
						upper = 100,
						control = list("diag.bestVal"=TRUE)
					)
				},
				error=function(cond) {
					print(paste("Problem:", d, " ", cond))
				})

        resultVector <- c(resultVector, abs(result$value-scores[n]))
        restarts <- c(restarts, result$restarts)

			  # FE indices according to CEC: 0, 10D, 20D, ..., 10000D
			  sampleFE <- seq(0, 10000 * d, by = 10 * d)

			  bestVal <- result$diagnostic$bestVal
			  L <- length(bestVal)
			  for (bb in seq_along(sampleFE)) {
			    fe <- sampleFE[bb]
			    if (fe == 0) {
			      idx <- 1
			    } else {
			      idx <- min(fe, L)
			    }
			    informMatrix[bb, i] <- abs(bestVal[idx] - scores[n])
			  }
      }
      write.table(resultVector, row.names = FALSE, col.names = FALSE, file = paste0(ALG_ID, "/N/N", n, "-D", d), sep = ",")
      write.table(informMatrix, row.names = FALSE, col.names = FALSE, file = paste0(ALG_ID, "/M/", ALG_ID, "_F", n, "_Min_EV.txt"), sep = ",")
      return( paste(paste0("CEC2017 N=", n, " D=", d), median(resultVector), min(resultVector), max(resultVector), mean(resultVector), sd(resultVector), mean(restarts), sep=",") )
    }
    cat(results, sep = "\n")
  }
  stopImplicitCluster()
  time.taken <- Sys.time() - start.time
  cat("Calculation time[hours]:", as.numeric(time.taken, units = "hours"), ",,,,,,\n")
}

CEC2017tableCreate <- function() {
  for (d in c(DIM)) {
    csvResults <- matrix(0, nrow = RUNS, ncol = 1)
    for (i in f_from:f_to) {
      resColumn <- read.table(paste0(ALG_ID, "/N/N", i, "-D", d), sep=",", header = FALSE)
      colnames(resColumn) <- paste0("P", i)
      csvResults <- cbind(csvResults, resColumn)
    }
    csvResults <- csvResults[, -1]
    write.csv(csvResults, file = paste0(ALG_ID, "/resTable-", d, ".csv"), row.names = TRUE)
  }
}

benchmarkParallel()
CEC2017tableCreate()
