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
#output_path <- "onepop_bi_errflat.vcf"
#error_rate <- 0.14

if (!file.exists(input_path)) {
  stop("No file found at the given path", call. = FALSE)
}

if (!(0 <= error_rate && error_rate <= 1)) {
  stop("Genotype error rate must be a number between 0 and 1", call. = FALSE)
}

suppressPackageStartupMessages({
library(VariantAnnotation)
})

flip_table <- list("0" = "1", "1" = "0")

flip_alleles <- function(alleles, error_rate, minor_alleless) {
  # detect if a given allele is a minor allele and roll a die to determine error
  is_minor <- alleles == minor_alleles
  is_error <- runif(n = length(alleles)) < error_rate

  # the allele will flip only if both are true
  to_flip <- is_minor & is_error

  # flip those allele states
  alleles[to_flip] <- unlist(flip_table[alleles[to_flip]])

  alleles
}


vcf <- readVcf(input_path)

# find out which 0 (REF) or 1 (ALT) allele states at each site are minor alleles
minor_alleles <- as.character(as.integer(unlist(info(vcf)$AF == info(vcf)$MAF)))

props <- c()

subset <- grep(pop, samples(header(vcf)), value = TRUE)
for (s in subset) {
  cat("Simulating errors in individual", s, "... ")

  # get a vector of (phased) genotypes of this sample and split it into two
  # vectors with alleles (one for each haplotype)
  gts <- geno(vcf)$GT[, s]
  alleles1 <- gsub("\\|.$", "", gts)
  alleles2 <- gsub("^.\\|", "", gts)

  # simulate errors at the given probability
  flipped1 <- flip_alleles(alleles1, error_rate)
  flipped2 <- flip_alleles(alleles2, error_rate)

  flipped_gts <- paste(flipped1, flipped2, sep = "|")

  geno(vcf)$GT[, s] <- flipped_gts

  cat("done! ")

  prop1 <- mean(alleles1[minor_alleles == alleles1] != flipped1[minor_alleles == alleles1])
  prop2 <- mean(alleles2[minor_alleles == alleles2] != flipped2[minor_alleles == alleles2])

  cat(sprintf("(haplotype 1 errors = %0.2f, haplotype 2 errors = %0.2f)\n", prop1, prop2))

  props <- c(props, prop1, prop2)
}

cat("-----\nAverage errors across all haplotypes =", mean(props), "\n")

file <- tempfile()
writeVcf(vcf, file)
system(paste("bgzip -c", file, ">", output_path))
