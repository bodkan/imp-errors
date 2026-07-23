vcfs := onepop.vcf.gz onepop_bi.vcf.gz onepop_bi_errorgt.vcf.gz onepop_bi_errorphase.vcf.gz

all: $(vcfs)

%.vcf.gz: sim_%.R
	Rscript $<

%_bi.vcf.gz: %.vcf.gz
	bcftools +fill-tags $< -- -t AF,MAF \
	  | bcftools view -m2 -M2 \
	  | bcftools view -e 'COUNT(GT="AA")=N_SAMPLES || COUNT(GT="RR")=N_SAMPLES' -Oz \
	  > $@

%_errorgt.vcf.gz: %.vcf.gz
	Rscript error_gt.R $< $@ 0.05 'p_'

%_errorphase.vcf.gz: %.vcf.gz
	Rscript error_phase.R $< $@ 0.03 'p_'

clean: 
	rm -f *.vcf.gz

