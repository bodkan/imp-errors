# check the OS type to assign appropriate Docker image tag
ifeq ($(shell uname -s), Darwin)
    PLATFORM ?= arm64
else
    PLATFORM ?= amd64
endif

IMAGE := bodkan/$(shell basename $(shell pwd)):$(PLATFORM)
CONTAINER := $(shell basename $(shell pwd))

# if present, extract GitHub access token
TOKEN := $(shell if [[ -f ~/.GITHUB_PAT ]]; then more ~/.GITHUB_PAT; else echo ""; fi)

RUN := docker run --rm -ti -v $(shell pwd):/project -w /project --name $(CONTAINER) $(IMAGE)

.PHONY: bash docker-build docker-build-clean

##################################################
# a couple of Docker shortcuts
#

bash:
	$(RUN) bash

docker-build:
	docker build --build-arg GITHUB_PAT=$(TOKEN) -t $(IMAGE) .

docker-build-clean:
	docker build --no-cache --build-arg GITHUB_PAT=$(TOKEN) -t $(IMAGE) .

docker-push:
	docker push $(IMAGE)

docker-pull:
	docker pull $(IMAGE)

##################################################
# the make pipeline rules themselves
#

models := onepop twopop
suffixes := .vcf.gz _bi.vcf.gz _bi_errorgt.vcf.gz _bi_errorphase.vcf.gz
vcfs := $(foreach m,$(models),$(addprefix $(m),$(suffixes)))

all: $(vcfs) summary

%.vcf.gz: sim_%.R
	$(RUN) Rscript $< $@ 42

%_bi.vcf.gz: %.vcf.gz
	$(RUN) bcftools +fill-tags $< -- -t AF,MAF \
	  | bcftools view -m2 -M2 \
	  | bcftools view -e 'COUNT(GT="AA")=N_SAMPLES || COUNT(GT="RR")=N_SAMPLES' -Oz \
	  > $@

%_errorgt.vcf.gz: %.vcf.gz
	$(RUN) Rscript error_gt.R $< $@ 0.05 'p1_'

%_errorphase.vcf.gz: %.vcf.gz
	$(RUN) Rscript error_phase.R $< $@ 0.03 'p1_'

# create summaries of VCF differences to check that:
#   - "original" VCFs must be the same as "error GT / phase" for panel
#   - "original" VCFs must differ from "error GT / phase" for target
# i.e., this will be the same genotypes:
#   - vimdiff panel_orig.txt panel_errorgt.txt
#   - vimdiff panel_orig.txt panel_errorphase.txt
# but these will be different:
#   - vimdiff target_orig.txt target_errorgt.txt
#   - vimdiff target_orig.txt target_errorphase.txt
summary: $(vcfs)
	echo p1_{1..100} | tr ' ' '\n' > list_target.txt
	echo p2_{1..100} | tr ' ' '\n' > list_panel.txt
	bcftools view -H --samples-file list_target.txt twopop_bi.vcf.gz            | cut -f 10- > target_orig.txt
	bcftools view -H --samples-file list_target.txt twopop_bi_errorgt.vcf.gz    | cut -f 10- > target_errorgt.txt
	bcftools view -H --samples-file list_target.txt twopop_bi_errorphase.vcf.gz | cut -f 10- > target_errorphase.txt
	bcftools view -H --samples-file list_panel.txt  twopop_bi.vcf.gz            | cut -f 10- > panel_orig.txt
	bcftools view -H --samples-file list_panel.txt  twopop_bi_errorgt.vcf.gz    | cut -f 10- > panel_errorgt.txt
	bcftools view -H --samples-file list_panel.txt  twopop_bi_errorphase.vcf.gz | cut -f 10- > panel_errorphase.txt

clean: 
	rm -f *.vcf.gz *.txt
