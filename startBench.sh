#!/bin/bash

ALG_ID=${1:-"CMAES"}
F_FROM=${2:-1}
F_TO=${3:-29}
DIM=${4:-30}

PID_FILE="$ALG_ID"_pid.txt

rm -f "$PID_FILE"
mkdir -p "$ALG_ID"/M "$ALG_ID"/N
cp CMAES.R "$ALG_ID"

nohup setsid Rscript CEC2017ParallelBenchmark.R "$ALG_ID" $F_FROM $F_TO $DIM > "$ALG_ID/$ALG_ID.csv" 2>&1 &
echo $! > "$PID_FILE"
