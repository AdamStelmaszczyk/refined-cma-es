#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)

if (length(args) < 2) {
  stop("Usage: Rscript rank.R ALG1 ALG2 [ALG3 ...]")
}

algsNames <- args
NUM_OF_ALGS <- length(algsNames)

globalAlgRanks = list()
for(algName in algsNames){
  globalAlgRanks[algName] = 0
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
  funPoints=optErrPoints+optSpeedPoints

  algRanks = list()

  for (ALG_NR in 1:length(algsNames)) {
    algName=algsNames[ALG_NR]
    algRanksSum = sum(funPoints[((RUNS*(ALG_NR-1)+1):(RUNS*ALG_NR))] )
    algRanks[algName] = algRanksSum
    globalAlgRanks[algName] = globalAlgRanks[algName][[1]] + algRanksSum
  }

  ord = order(unlist(algRanks), decreasing = T)

  cat("F", funNmbr, "ranks:", paste(names(algRanks[ord]), algRanks[ord], sep = " = ", collapse = ", "), "\n")
}
ord = order(unlist(globalAlgRanks), decreasing = T)
cat("Ranks:", paste(names(globalAlgRanks[ord]), globalAlgRanks[ord], sep = " = ", collapse = ", "), "\n")

leaderPoints = unlist(globalAlgRanks)[ord[1]]
secondPoints = unlist(globalAlgRanks)[ord[2]]
cat("Leads by:", leaderPoints - secondPoints, "points\n")
