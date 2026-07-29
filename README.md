### Setup

The whole pipeline is implemented using Make and R running in single
reproducible Docker container.

You can build the container yourself by running this first:

```
make docker-build
```

### Example use

Each individual Make rule runs a single command inside Docker. Below, I'm
showing those rules when run with the `-n` flag ("dry run"), which only prints
the commands to be run, without actually running them (just like one would with
Snakemake).

Note that this always takes the form of this "prefix":

```
docker run --rm -ti -v /maps/projects/racimolab/people/krd114/imp-errors:/project -w /project --name imp-errors imp-errors:amd64
```

followed (on the same line!) by the actual script or bcftools command. This
simply means that the latter is what's to be run inside the container. If you
want to run a different script, or a different command inside the container,
you can use the same trick.

(I know the `docker run ...` command is annoyingly long. That's why I wrapped
this pipeline in Make, hoping to make it easier even if you don't know Docker.)

#### 1. Simulation of genotype data

The script `sim_onepop.R` runs a simple, single-population simulation (sequence
length, recombination rate, mutation rate, etc., are currently hardcoded in
it).

Its first argument is the produced VCF file, the second argument is a random
seed.

In the current toy pipeline, it produces the file `onepop.vcf.gz`.

(Of course, in our real-world setting, this could be a more complex simulation
script, as long as it also produces a VCF file with the `ts_vcf()` _slendr_
function.)

```
> make -n onepop.vcf.gz
docker run --rm -ti -v /maps/projects/racimolab/people/krd114/imp-errors:/project -w /project --name imp-errors imp-errors:amd64 \
    Rscript sim_onepop.R onepop.vcf.gz 42
```

#### 2. Filter to biallelic sites only

This `bcftools` command takes in `onepop.vcf.gz` simulated in the previous step
and produces file `output_bi.vcf.gz`.

```
> make -n onepop_bi.vcf.gz
docker run --rm -ti -v /maps/projects/racimolab/people/krd114/imp-errors:/project -w /project --name imp-errors imp-errors:amd64 \
    bcftools +fill-tags onepop.vcf.gz -- -t AF,MAF \
      | bcftools view -m2 -M2 \
      | bcftools view -e 'COUNT(GT="AA")=N_SAMPLES || COUNT(GT="RR")=N_SAMPLES' -Oz \
      > onepop_bi.vcf.gz
```

#### 3a. Simulate genotype imputation errors in a given population at a given rate

Genotype imputation errors are simulated with the `error_gt.R` script,
accepting input VCF file as its first argument, output VCF file as its second
argument, and the appropriate genotype error rate (a number between 0 and 1) as
its third argument.

(A new fourth argument has been added (the last argument in the command below)
which represents a "prefix" of a population name (here `'p_'`) or, if multiple
populations should be processed a regex capturing their names (this could be,
for instance, something like `'p1_|p2_'`, to process samples from populations
`p1` and `p2`).)

```
> make -n onepop_bi_errorgt.vcf.gz
docker run --rm -ti -v /maps/projects/racimolab/people/krd114/imp-errors:/project -w /project --name imp-errors imp-errors:amd64 \
    Rscript error_gt.R onepop_bi.vcf.gz onepop_bi_errorgt.vcf.gz 0.05 'p_'
```

#### 3b. Simulate phase switch errors in a given population at a given rate

Phase switch errors are simulated with the `error_phase.R` script, accepting
input VCF file as its first argument, output VCF file as its second argument,
the appropriate phase error rate (a number between 0 and 1) as its third
argument.

(Again, a new fourth argument has been added with the same meaning as described
in point 3a.)

```
> make -n onepop_bi_errorphase.vcf.gz
docker run --rm -ti -v /maps/projects/racimolab/people/krd114/imp-errors:/project -w /project --name imp-errors imp-errors:amd64 \
    Rscript error_phase.R onepop_bi.vcf.gz onepop_bi_errorphase.vcf.gz 0.03 'p_'
```

#### (4. Combining the two error simulations)

Of course, both 3a. and 3b. could be combined together to layer both kinds of
errors in the same VCF.
