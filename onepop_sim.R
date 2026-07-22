library(slendr)
init_env(uv = TRUE)

filename <- "onepop_gt.vcf.gz"

population("p", time = 1000, N = 10000) %>%
  compile_model(generation_time = 1, direction = "backward") %>%
  msprime(sequence_length = 1000, recombination_rate = 1e-8, random_seed = 42) %>%
  ts_mutate(mutation_rate = 1e-5, random_seed = 42) %>%
  ts_vcf(filename, individuals = paste("p", 1:50, sep = "_"))
