import platform
import sys

# check the OS type to assign appropriate Docker image tag
if platform.system() == "Darwin":
    PLATFORM = "arm64"
elif platform.system() == "Linux":
    PLATFORM = "amd64"
else:
    sys.exit("Unsupported operating system")

# container image to pull from a remote repository
IMAGE = f"bodkan/imp-errors:{PLATFORM}"

# use containers for every rule in this Snakefile
container: "docker://" + IMAGE

# dummy models and errors to simulate
MODELS = ["onepop", "twopop"]
ERRORS = ["errorgt", "errorphase"]

rule all:
    input:
        vcf=expand("{model}_bi_{error}.vcf.gz", model=MODELS, error=ERRORS)

rule simulate_vcf:
    input:
        script="sim_{model}.R"
    output:
        vcf="{model}.vcf.gz"
    shell:
        "HOME=/root Rscript {input.script} {output.vcf} 42"

rule filter_biallelic:
    input:
        vcf="{model}.vcf.gz"
    output:
        vcf="{model}_bi.vcf.gz"
    shell:
        """
        bcftools +fill-tags {input.vcf} -- -t AF,MAF \
         | bcftools view -m2 -M2 \
         | bcftools view -e 'COUNT(GT="AA")=N_SAMPLES || COUNT(GT="RR")=N_SAMPLES' -Oz \
          > {output.vcf}
        """

rule simulate_gt_errors:
    input:
        vcf="{model}_bi.vcf.gz"
    output:
        vcf="{model}_bi_errorgt.vcf.gz"
    shell:
        "HOME=/root Rscript error_gt.R {input.vcf} {output.vcf} 0.05 'p1_'"

rule simulate_phase_errors:
    input:
        vcf="{model}_bi.vcf.gz"
    output:
        vcf="{model}_bi_errorphase.vcf.gz"
    shell:
        "HOME=/root Rscript error_phase.R {input.vcf} {output.vcf} 0.05 'p1_'"

rule clean: 
    shell:
        "rm -f *.vcf.gz *.txt"
