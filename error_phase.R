# The standard measure of phase accuracy for genome-scale data is the switch
# error rate,8–12 which is the proportion of pairs of consecutive heterozygotes
# that are incorrectly phased.
# -- https://www.cell.com/ajhg/fulltext/S0002-9297(22)00206-3

args <- commandArgs(trailingOnly = TRUE)

#if (length(args) != 3) {
#  stop("Path to input VCF, output VCF, and error rate [0, 1] must be specified", call. = FALSE)
#}

#input_path <- args[1]
#output_path <- args[2]
#error_rate <- as.numeric(args[3])
input_path <- "onepop_gt_bi.vcf.gz"
output_path <- "onepop_gt_bi_errphase.vcf.gz"
error_rate <- 0.1

#if (!file.exists(input_path)) {
#  stop("No file found at the given path", call. = FALSE)
#}
#
#if (!(0 <= error_rate && error_rate <= 1)) {
#  stop("Switch error rate must be a number between 0 and 1", call. = FALSE)
#}

suppressPackageStartupMessages({
library(VariantAnnotation)
})

vcf <- readVcf(input_path)

#header(vcf)
#samples(header(vcf))
#geno(header(vcf))
#info(vcf)

props <- c()

for (s in samples(header(vcf))) {
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
  compare$switch[to_switch] <- "here"
  geno(vcf)$GT[, s] <- switched_gts

  cat("done! ")

  prop <- mean(switch_events, na.rm = TRUE)

  cat(sprintf("(switch error = %0.2f at %d het sites)\n", prop, length(het_sites)))

  props <- c(props, prop)
}

cat("-----\nAverage switch errors across all samples =", mean(props, na.rm = TRUE), "\n")

file <- tempfile()
writeVcf(vcf, file)
system(paste("bgzip -c", file, ">", output_path))
