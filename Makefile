vcfs := onepop_gt.vcf.gz onepop_gt_bi.vcf.gz onepop_gt_bi_errflat.vcf.gz

all: $(vcfs)

%_gt.vcf.gz: %_sim.R
	Rscript $<

%_bi.vcf.gz: %.vcf.gz
	bcftools +fill-tags $< -- -t AF,MAF \
	  | bcftools view -m2 -M2 \
	  | bcftools view -e 'COUNT(GT="AA")=N_SAMPLES || COUNT(GT="RR")=N_SAMPLES' -Oz \
	  > $@

%_bi_errflat.vcf.gz: %_bi.vcf.gz
	Rscript error_gt.R $< $@ 0.17

clean: 
	rm -f *.vcf.gz

