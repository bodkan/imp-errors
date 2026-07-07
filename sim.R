library(slendr)
init_env(uv = TRUE)

vcf_sim <- "gt_sim.vcf.gz"
vcf_maf <- "gt_maf.vcf.gz"

population("p", time = 1000, N = 10000) %>%
  compile_model(generation_time = 1, direction = "backward") %>%
  msprime(sequence_length = 1000, recombination_rate = 1e-8, random_seed = 42) %>%
  ts_mutate(mutation_rate = 1e-5, random_seed = 42) %>%
  ts_vcf(vcf_sim, individuals = paste("p", 1:50, sep = "_"))

system(paste(
  "bcftools +fill-tags", vcf_sim, "-- -t MAF",
  "|",
  "bcftools view -m2 -M2",
  "|",
  "bcftools view -e 'COUNT(GT=\"AA\")=N_SAMPLES || COUNT(GT=\"RR\")=N_SAMPLES'",
  "-Oz -o", vcf_maf
))
