#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)

if (length(args) < 2) {
  stop("Usage: ./CEC26ranking.R ALG1 ALG2 [ALG3 ...]")
}

algsNames <- args
NUM_OF_ALGS <- length(algsNames)

globalAlgRanks = list()
globalAccuracyRanks = list()
globalSpeedRanks = list()

for(algName in algsNames){
  globalAlgRanks[algName] = 0
  globalAccuracyRanks[algName] = 0
  globalSpeedRanks[algName] = 0
}

DIM = 30
RUNS = 25

FESby = 10*DIM
MaxFES = 10000*DIM

dumpAtFESSeq = c(1, seq(FESby, MaxFES, by=FESby))
dumpAtFESLen = length(dumpAtFESSeq)

for (funNmbr in 1:29) {
  bests4runs = vector( mode="numeric", length=RUNS*NUM_OF_ALGS )
  stops4runs = vector( mode="numeric", length=RUNS*NUM_OF_ALGS )
  ALG_NR = 1
  for (algName in algsNames) {
    # cecTable
    cecFullTable = read.table(paste0("data/", algName, "/M/", algName, "_F", funNmbr, "_Min_EV.txt"), header=F, sep=",")
    bests4runs[(1+RUNS*(ALG_NR-1)):(RUNS*ALG_NR)] = as.numeric(cecFullTable[dumpAtFESLen,])
    # find stagnation FEs
    for( runNmbr in 0:(RUNS-1)){
      lastErr=cecFullTable[dumpAtFESLen, runNmbr+1]
      dumpIndx =dumpAtFESLen-1
      while(dumpIndx >= 1 && lastErr==cecFullTable[dumpIndx, runNmbr+1]){
        dumpIndx=dumpIndx-1
      }
      # cecFullTable[dumpIndx+1, runNmbr+1]
      stops4runs[runNmbr+1+RUNS*(ALG_NR-1)] = dumpAtFESSeq[dumpIndx+1]
    }
    ALG_NR = ALG_NR + 1
  }
  optErrPoints = NUM_OF_ALGS*RUNS - rank(bests4runs)
  optSpeedPoints = NUM_OF_ALGS*RUNS - rank(stops4runs)
  funPoints = optErrPoints + optSpeedPoints

  algRanks = list()

  for (ALG_NR in 1:length(algsNames)) {
    algName = algsNames[ALG_NR]
    runIdxs = ((RUNS*(ALG_NR-1)+1):(RUNS*ALG_NR))
    accPointsSum = sum(optErrPoints[runIdxs])
    speedPointsSum = sum(optSpeedPoints[runIdxs])
    algRanksSum = sum(funPoints[runIdxs])
    algRanks[algName] = algRanksSum
    globalAlgRanks[algName] = globalAlgRanks[algName][[1]] + algRanksSum
    globalAccuracyRanks[algName] = globalAccuracyRanks[algName][[1]] + accPointsSum
    globalSpeedRanks[algName] = globalSpeedRanks[algName][[1]] + speedPointsSum
  }

  ord = order(unlist(algRanks), decreasing = T)

  cat(paste0("F", funNmbr), paste(names(algRanks[ord]), algRanks[ord], sep = " = ", collapse = ", "), "\n")
}

ord = order(unlist(globalAlgRanks), decreasing = T)
cat("\nTotal score:   ", paste(names(globalAlgRanks[ord]), globalAlgRanks[ord], sep = " = ", collapse = ", "), "\n")

# Accuracy ranking (posortowane wg Accuracy)
ordAcc = order(unlist(globalAccuracyRanks), decreasing = T)
cat("Accuracy score:", paste(names(globalAccuracyRanks[ordAcc]), globalAccuracyRanks[ordAcc], sep = " = ", collapse = ", "), "\n")

# Speed ranking (posortowane wg Speed)
ordSpeed = order(unlist(globalSpeedRanks), decreasing = T)
cat("Speed score:   ", paste(names(globalSpeedRanks[ordSpeed]), globalSpeedRanks[ordSpeed], sep = " = ", collapse = ", "), "\n")

leaderPoints = unlist(globalAlgRanks)[ord[1]]
secondPoints = unlist(globalAlgRanks)[ord[2]]
cat("\nLeads by:", leaderPoints - secondPoints, "points\n")
