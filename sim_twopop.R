args <- commandArgs(trailingOnly = TRUE)

if (length(args) != 2) {
  stop("Output VCF and random seed for the simulation must be provided", call. = FALSE)
}

vcf <- args[1]
random_seed <- as.integer(args[2])

#vcf <- "twopop.vcf.gz"
#random_seed <- 42

suppressPackageStartupMessages(library(slendr))
init_env()

p1 <- population("p1", time = 1000, N = 10000)
p2 <- population("p2", time = 500, N = 10000, parent = p1)

model <- compile_model(list(p1, p2), generation_time = 1, direction = "backward")

msprime(model, sequence_length = 1e6, recombination_rate = 1e-8, random_seed = random_seed) %>%
  ts_mutate(mutation_rate = 1e-8, random_seed = random_seed) %>%
  ts_vcf(vcf, individuals = c(paste("p1", 1:100, sep = "_"),
                              paste("p2", 1:100, sep = "_")))
