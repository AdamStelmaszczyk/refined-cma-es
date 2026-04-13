#!/usr/bin/env Rscript

library(cec2017)
source("CMAES.R")

args <- commandArgs(trailingOnly = TRUE)

DO_T1 <- "-t1" %in% args || length(args) == 0
DO_T2 <- "-t2" %in% args || length(args) == 0

DIM <- 30
EVALS <- 10000

funcs <- c(1, 3:30)

if (DO_T1) {
  times_T1 <- numeric(length(funcs))

  for (i in seq_along(funcs)) {
    f <- funcs[i]
    x <- matrix(runif(EVALS * DIM, -100, 100), nrow = EVALS)
    t0 <- proc.time()[3]
    for (j in 1:EVALS) {
      cec2017(f, x[j, ])
    }
    t1 <- proc.time()[3]

    times_T1[i] <- t1 - t0
    cat(sprintf("f%d %.1fs\n", f, times_T1[i]))
  }

  T1 <- mean(times_T1)
  cat("\nT1 =", T1, "s\n\n")
}

if (DO_T2) {
  times_T2 <- numeric(length(funcs))

  for (i in seq_along(funcs)) {
    f <- funcs[i]
    eval_counter <- 0

    fn_wrapped <- function(x) {
      eval_counter <<- eval_counter + 1
      cec2017(f, x)
    }

    t0 <- proc.time()[3]

    cmaes(
      runif(DIM, -100, 100),
      fn = fn_wrapped,
      lower = -100,
      upper = 100,
      control = list("budget"=EVALS)
    )

    t1 <- proc.time()[3]
    times_T2[i] <- t1 - t0

    cat(sprintf("f%d %.1fs (evals=%d)\n", f, times_T2[i], eval_counter))
  }

  T2 <- mean(times_T2)
  cat("\nT2 =", T2, "s\n\n")
}

if (DO_T1 && DO_T2) {
  complexity <- (T2 - T1) / T1
  cat("Algorithm complexity =", complexity, "\n")
}
