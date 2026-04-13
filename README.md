# _Refined CMA-ES for CEC 2026 Bound-Constrained Single-Objective Optimization_

Adam Stelmaszczyk, Rafał Biedrzycki, Jarosław Arabas  
Institute of Computer Science, Warsaw University of Technology

## Installation

Experiments were conducted using R version 4.3.1. We prepared the Dockerfile for reproducability.

To use it, install e.g. podman (https://podman.io/docs/installation), on *nix:
```
apt install podman
```
Navigate to the directory containing `Dockerfile` and build a `cmaes` image (it takes about a minute):
```
podman build -t cmaes .
```

Alternatively, you can recreate the R environment on your host following the Dockerfile (you need to install R dependencies). But, make sure you have `R --version` 4.3.1.

## Running

Start a container and step into it with bash:

```
podman run -it --entrypoint bash cmaes
```

Start a chosen script (`./startBench.sh`, `./stopBench.sh`, `./CEC26ranking.R`, `./complexity.R`, `./table.py`):

```
root@63344f184cc5:/app# ./startBench.sh CMAES 1 3 2
```

`./startBench.sh` creates a dir `CMAES` benchmarking f1-f3 in 2 dimensions. This tiny benchmark runs in about a minute. Every CEC function runs in a separate process, so maximally there will be 29 processes (this will be capped by your maximium number of logical CPU cores). So in the begining, 3 processes for f1-f3 are spawn. f1 finishes its process with run 1, then f1 run 2 is spawned etc. You can view the processes in `top`.

Data appears in the `CMAES/N` and `CMAES/M` directories. To view it you can use `ls`, `more`, `head` etc.
In the end, in `CMAES/CMAES.csv` you can view a summary:

```
root@53e2cbf63eb4:/app# cat CMAES/CMAES.csv 
Problem(N=Dim D=Problem),Median, Best, Worst, Mean, Sd, Restarts
[1] CEC2017 N=1 D=2,0,0,0,0,0,0         CEC2017 N=2 D=2,100,100,100,100,0,0
[3] CEC2017 N=3 D=2,100,100,100,100,0,0
[1] Calculation time[hours]:  0.0194749187098609 ,,,,,,
```

You can also download the files from the container to your host - while having the container running, execute this in a second command line tab on your host:
```
podman cp 53e2cbf63eb4:CMAES/CMAES.csv .
```

## Clean up

List your images:
```
podman images
```

Remove one image:
```
podman rmi -f IMAGE_ID
```

Remove all images:
```
podman rmi -f $(podman images -q)
```

List all containers:
```
podman ps -a
```

Remove ~everything (images, containers...):
```
podman system prune -a
```
