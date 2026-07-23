models := onepop
suffixes := .vcf.gz _bi.vcf.gz _bi_errorgt.vcf.gz _bi_errorphase.vcf.gz
vcfs := $(foreach m,$(models),$(addprefix $(m),$(suffixes)))

all: $(vcfs)

%.vcf.gz: sim_%.R
	time Rscript $< $@ 42

%_bi.vcf.gz: %.vcf.gz
	time bcftools +fill-tags $< -- -t AF,MAF \
	  | bcftools view -m2 -M2 \
	  | bcftools view -e 'COUNT(GT="AA")=N_SAMPLES || COUNT(GT="RR")=N_SAMPLES' -Oz \
	  > $@

%_errorgt.vcf.gz: %.vcf.gz
	time Rscript error_gt.R $< $@ 0.05 'p_'

%_errorphase.vcf.gz: %.vcf.gz
	time Rscript error_phase.R $< $@ 0.03 'p_'

clean: 
	rm -f *.vcf.gz log.txt

