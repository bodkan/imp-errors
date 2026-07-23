args <- commandArgs(trailingOnly = TRUE)

if (length(args) != 4) {
  stop("Input VCF, output VCF, error rate [0, 1], and population name(s) regex must be specified",
       call. = FALSE)
}

input_path <- args[1]
output_path <- args[2]
error_rate <- as.numeric(args[3])
pop <- args[4]
#input_path <- "onepop_bi.vcf.gz"
#output_path <- "onepop_bi_errphase.vcf.gz"
#error_rate <- 0.1

if (!file.exists(input_path)) {
  stop("No file found at the given path", call. = FALSE)
}

if (!(0 <= error_rate && error_rate <= 1)) {
  stop("Phase switch error rate must be a number between 0 and 1", call. = FALSE)
}

suppressPackageStartupMessages({
library(VariantAnnotation)
})

vcf <- readVcf(input_path)

props <- c()

subset <- grep(pop, samples(header(vcf)), value = TRUE)
for (s in subset) {
  cat("Simulating errors in individual", s, "... ")

  # get a vector of (phased) genotypes of this sample and split it into two
  # vectors with alleles (one for each haplotype)
  gts <- geno(vcf)$GT[, s]

  alleles1 <- gsub("\\|.$", "", gts)
  alleles2 <- gsub("^.\\|", "", gts)

  # find indices of all heterozygotes...
  het_sites <- which(alleles1 != alleles2)
  # ... then determine which one of them will trigger a phase switch
  probs <- runif(n = length(het_sites))
  switch_events <- probs < error_rate

  # aggregate the number of cumulative switches accross all het sites
  switch_counts <- cumsum(switch_events)
  # each "even switch count" effectively restores the original phase (no switch),
  # and each "odd switch count" indicates a phase switch starting from that site
  switch_states <- (switch_counts %% 2) == 1

  # switch genotypes accordingly
  to_switch <- het_sites[switch_states]
  switched_gts <- gts
  switched_gts[to_switch] <- paste0(alleles2[to_switch], "|", alleles1[to_switch])

  compare <- data.frame(original = gts, switched = switched_gts)
  compare$switch <- "-"
  compare$switch[to_switch] <- "flipped"
  compare$switch[het_sites[switch_events]] <- "switch"
  geno(vcf)$GT[, s] <- switched_gts

  cat("done! ")

  prop <- mean(switch_events, na.rm = TRUE)

  if (VERBOSE)
    cat(sprintf("(switch error = %0.2f at %d het sites)\n", prop, length(het_sites)))

  props <- c(props, prop)
}

if (VERBOSE) cat("-----\n")
cat("Average switch errors across all samples =", mean(props, na.rm = TRUE), "\n")

file <- tempfile()
writeVcf(vcf, file)
system(paste("bgzip -c", file, ">", output_path))
