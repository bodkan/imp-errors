args <- commandArgs(trailingOnly = TRUE)

if (length(args) != 2) {
  stop("Output VCF and random seed for the simulation must be provided", call. = FALSE)
}

vcf <- args[1]
random_seed <- as.integer(args[2])

#vcf <- "onepop.vcf.gz"
#random_seed <- 42

suppressPackageStartupMessages(library(slendr))
init_env()

population("p", time = 1000, N = 10000) %>%
  compile_model(generation_time = 1, direction = "backward") %>%
  msprime(sequence_length = 1e6, recombination_rate = 1e-8, random_seed = random_seed) %>%
  ts_mutate(mutation_rate = 1e-8, random_seed = random_seed) %>%
  ts_vcf(vcf, individuals = paste("p", 1:100, sep = "_"))
