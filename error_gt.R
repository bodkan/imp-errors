suppressPackageStartupMessages({
library(VariantAnnotation)
library(ggplot2)
library(dplyr)
})

flip_table <- list("0" = "1", "1" = "0")

flip_alleles <- function(alleles, error_prob, minor_alleless) {
  # detect if a given allele is a minor allele and roll a die to determine error
  is_minor <- alleles == minor_alleles
  is_error <- runif(n = length(alleles)) < error_prob

  # the allele will flip only if both are true
  to_flip <- is_minor & is_error

  # flip those allele states
  alleles[to_flip] <- unlist(flip_table[alleles[to_flip]])

  alleles
}

#args <- commandArgs(trailingOnly = TRUE)
#
#if (length(args) != 1) {
#  stop("A single argument specifying the path to a VCF file must be given", call. = FALSE)
#}
#
#path <- args[1]
path <- "onepop_gt_bi.vcf.gz"
error_prob <- 0.1

if (!file.exists(path)) {
  stop("No file found at the given path", call. = FALSE)
}

info <- Seqinfo(seqnames = "chr1", seqlengths = 1000, isCircular = FALSE, genome = "slendr")
vcf <- readVcf(path, genome = info)

#header(vcf)
#samples(header(vcf))
#geno(header(vcf))
#info(vcf)

# find out which 0 (REF) or 1 (ALT) allele states at each site are minor alleles
minor_alleles <- as.character(as.integer(unlist(info(vcf)$AF == info(vcf)$MAF)))

for (s in samples(header(vcf))) {
  cat("Simulating errors in individual", s, "... ")

  gts <- geno(vcf)$GT[, s]

  alleles1 <- gsub("\\|.$", "", gts)
  alleles2 <- gsub("^.\\|", "", gts)

  flipped1 <- flip_alleles(alleles1, error_prob)
  flipped2 <- flip_alleles(alleles2, error_prob)

  mean(alleles1 != flipped1)
  mean(alleles2 != flipped2)

  flipped_gts <- paste(flipped1, flipped2, sep = "|")

  geno(vcf)$GT[, s] <- flipped_gts

  cat("done!\n")
}

writeVcf(vcf, "onepop_gt_bi_errflat.vcf.gz")
