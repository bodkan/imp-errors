import os
import platform
import sys

# check the OS type to get the appropriate name of the Docker image
if platform.system() == "Darwin":
    IMAGE = f"bodkan/imp-errors:arm64"
elif platform.system() == "Linux":
    IMAGE = f"bodkan/imp-errors:amd64"
else:
    sys.exit("Unsupported operating system")

# A custom function to pass a given shell command to Docker. Intended
# to be used inside a `shell:` rule in Snakemake.
def run_docker(cmd):
    return f"docker run --rm -ti -v {os.getcwd()}:/project -w /project {IMAGE} {cmd}"

# dummy models to simulate
MODELS = ["onepop", "twopop"]

rule all:
    input:
        vcf=expand("{model}_bi.vcf.gz", model=MODELS)

rule simulate_vcf:
    input:
        script="sim_{model}.R"
    output:
        vcf="{model}.vcf.gz"
    shell:
        run_docker("Rscript {input.script} {output.vcf} 42")

rule filter_biallelic:
    input:
        vcf="{model}.vcf.gz"
    output:
        vcf="{model}_bi.vcf.gz"
    shell:
        run_docker(
        """bcftools +fill-tags {input.vcf} -- -t AF,MAF \
         | bcftools view -m2 -M2 \
         | bcftools view -e 'COUNT(GT="AA")=N_SAMPLES || COUNT(GT="RR")=N_SAMPLES' -Oz \
          > {output.vcf}
        """
        )

rule simulate_gt_errors:
    input:
        vcf="{model}_bi.vcf.gz"
    output:
        vcf="{model}_bi_errorgt.vcf.gz"
    shell:
        run_docker("Rscript error_gt.R {input.vcf} {output.vcf} 0.05 'p1_'")

rule simulate_phase_errors:
    input:
        vcf="{model}_bi.vcf.gz"
    output:
        vcf="{model}_bi_errorphase.vcf.gz"
    shell:
        run_docker("Rscript error_phase.R {input.vcf} {output.vcf} 0.05 'p1_'")

rule clean: 
    shell:
        "rm -f *.vcf.gz *.txt"
