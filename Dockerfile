FROM bioconductor/bioconductor_docker:3.23-r-4.6.1

RUN apt-get update && apt-get install -y --no-install-recommends \
    bcftools make \
    && rm -rf /var/lib/apt/lists/*

RUN Rscript -e 'install.packages("pak", repos = "https://r-lib.github.io/p/pak/stable/")'
RUN Rscript -e 'pak::pkg_install("slendr")'
RUN Rscript -e 'BiocManager::install("VariantAnnotation")'

WORKDIR /project
