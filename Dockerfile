FROM docker.io/library/r-base:4.4.1

WORKDIR /app

RUN apt-get update && apt-get install -y \
    python3 \
    python3-numpy \
    python3-scipy \
    texlive-latex-base \
    texlive-latex-recommended \
    procps \
    && rm -rf /var/lib/apt/lists/*

RUN R -e "install.packages(c('foreach','doParallel'), repos='https://cloud.r-project.org')"

COPY . .

RUN R CMD INSTALL cec2017_0.3.0.tar.gz

ENTRYPOINT ["Rscript"]
