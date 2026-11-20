FROM bioconductor/bioconductor_docker:3.23-r-4.6.1

RUN apt-get update && apt-get install -y --no-install-recommends \
    bcftools make \
    && rm -rf /var/lib/apt/lists/*

RUN Rscript -e 'install.packages("slendr")'
RUN Rscript -e 'slendr::setup_env(env = "venv", agree = TRUE)'
RUN Rscript -e 'BiocManager::install("VariantAnnotation")'

WORKDIR /project
