FROM docker.io/library/r-base:4.3.1

WORKDIR /app

RUN R -e "install.packages(c('foreach','doParallel'), repos='https://cloud.r-project.org')"

COPY . .

RUN R CMD INSTALL cec2017_0.3.0.tar.gz

ENTRYPOINT ["Rscript"]
