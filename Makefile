# check the OS type to assign appropriate Docker image tag
ifeq ($(shell uname -s), Darwin)
    PLATFORM ?= arm64
else
    PLATFORM ?= amd64
endif

IMAGE := $(shell basename $(shell pwd)):$(PLATFORM)
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

##################################################
# the make pipeline rules themselves
#

models := onepop
suffixes := .vcf.gz _bi.vcf.gz _bi_errorgt.vcf.gz _bi_errorphase.vcf.gz
vcfs := $(foreach m,$(models),$(addprefix $(m),$(suffixes)))

all: $(vcfs)

%.vcf.gz: sim_%.R
	$(RUN) Rscript $< $@ 42

%_bi.vcf.gz: %.vcf.gz
	$(RUN) bcftools +fill-tags $< -- -t AF,MAF \
	  | bcftools view -m2 -M2 \
	  | bcftools view -e 'COUNT(GT="AA")=N_SAMPLES || COUNT(GT="RR")=N_SAMPLES' -Oz \
	  > $@

%_errorgt.vcf.gz: %.vcf.gz
	$(RUN) Rscript error_gt.R $< $@ 0.05 'p_'

%_errorphase.vcf.gz: %.vcf.gz
	$(RUN) Rscript error_phase.R $< $@ 0.03 'p_'

clean: 
	rm -f *.vcf.gz log.txt
