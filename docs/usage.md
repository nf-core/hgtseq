# nf-core/hgtseq: Usage

## :warning: Please read this documentation on the nf-core website: [https://nf-co.re/hgtseq/usage](https://nf-co.re/hgtseq/usage)

> _Documentation of pipeline parameters is generated automatically from the pipeline schema and can no longer be found in markdown files._

## Introduction

**nf-core/hgtseq** is a bioinformatics best-practice analysis pipeline for investigating horizontal gene transfer from NGS data.

## Topic introduction

The pipeline accepts either a FASTQ with raw paired-end reads from Illumina sequencing as input, or an already aligned paired-end BAM file. Raw reads are first trimmed for quality and Illumina adapters: the resulting high quality reads are aligned to the host genome, which is defined by its identifier in the iGenomes repository for seamless download, and via NCBI taxonomic identifier. Pre-aligned BAM files are then processed in parallel to extract 2 categories of reads, via their SAM bitwise flags. With bitwise flag 13, we extract reads classified as paired, which are unmapped and whose mate is also unmapped (i.e. both mates unmapped). With bitwise flag 5 we extract reads classified as paired, which are unmapped but whose mate is mapped (i.e. only one mate unmapped in a pair). In both cases we use flag 256 to exclude non-primary alignments. Both categories are classified using kraken2.

The second category, i.e. unmapped reads whose mate is mapped, provide the opportunity to infer the potential genomic location of an integration event, if confirmed, by using the information available for the properly mapped mate in the pair: for this category of reads, the pipeline parses the genomic coordinates of the mate from the BAM file, and merges them with the unmapped reads classified by kraken2. Finally, host-classified reads are filtered out and the data are used to generate krona plots and an HTML report with RMarkdown.

## Input Formats

The input file can have at least two or three columns according to the format of reads used, i.e. two columns for BAM files and three for FASTQ files (as defined in the tables below).

### FASTQ

The FASTQ file extension can be either _fastq.gz_ or _fastq_.

```console
sample,input1,input2
testsample01,/path/to/file1_1.fastq.gz/path/to/file1_2.fastq.gz
testsample02,/path/to/file2_1.fastq.gz,/path/to/file2_2.fastq.gz
testsample03,/path/to/file3_1.fastq,/path/to/file3_2.fastq.gz
```

| Column   | Description                                                                                                                                                                            |
| -------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `sample` | Custom sample name. This entry will be identical for multiple sequencing libraries/runs from the same sample. Spaces in sample names are automatically converted to underscores (`_`). |
| `input1` | Full path to FastQ file for Illumina short reads 1. File can be either _fastq.gz_ or _fastq_.                                                                                          |
| `input2` | Full path to FastQ file for Illumina short reads 2. File can be either _fastq.gz_ or _fastq_.                                                                                          |

An [example samplesheet](../assets/samplesheet_fastq.csv) has been provided with the pipeline.

### BAM

```console
sample,input1
testsample01,/path/to/file1.bam
testsample02,/path/to/file2.bam
testsample03,/path/to/file3.bam
```

| Column   | Description                                                                                                                                                                            |
| -------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `sample` | Custom sample name. This entry will be identical for multiple sequencing libraries/runs from the same sample. Spaces in sample names are automatically converted to underscores (`_`). |
| `input1` | Full path to aligned BAM file.                                                                                                                                                         |

An [example samplesheet](../assets/samplesheet_bam.csv) has been provided with the pipeline.

## Running the pipeline

The typical command for running the pipeline is as follows:

```console
nextflow run nf-core/hgtseq \
--input samplesheet.csv \
--outdir <OUTDIR> \
--genome GRCh38 \
--taxonomy_id "TAXID" \
-profile <singularity,docker,conda> \
--krakendb /path/to/kraken_db \
--kronadb /path/to/krona_db/taxonomy.tab
```

This will launch the pipeline with the `singularity`, `docker` or `conda` configuration profile. See below for more information about profiles.

Note that the pipeline will create the following files in your working directory:

```bash
work                # Directory containing the nextflow working files
<OUTDIR>            # Finished results in specified location (defined with --outdir)
.nextflow_log       # Log file from Nextflow
# Other nextflow hidden files, eg. history of pipeline runs and old logs.
```

If you wish to repeatedly use the same parameters for multiple runs, rather than specifying each flag in the command, you can specify these in a params file.

Pipeline settings can be provided in a `yaml` or `json` file via `-params-file <file>`.

> ⚠️ Do not use `-c <file>` to specify parameters as this will result in errors. Custom config files specified with `-c` must only be used for [tuning process resource specifications](https://nf-co.re/docs/usage/configuration#tuning-workflow-resources), other infrastructural tweaks (such as output directories), or module arguments (args).
> The above pipeline run specified with a params file in yaml format:

```bash
nextflow run nf-core/hgtseq -profile docker -params-file params.yaml
```

with `params.yaml` containing:

```yaml
input: './samplesheet.csv'
outdir: './results/'
genome: 'GRCh37'
input: 'data'
<...>
```

You can also generate such `YAML`/`JSON` files via [nf-core/launch](https://nf-co.re/launch).

### Updating the pipeline

When you run the above command, Nextflow automatically pulls the pipeline code from GitHub and stores it as a cached version. When running the pipeline after this, it will always use the cached version if available - even if the pipeline has been updated since. To make sure that you're running the latest version of the pipeline, make sure that you regularly update the cached version of the pipeline:

```bash
nextflow pull nf-core/hgtseq
```

### Reproducibility

It is a good idea to specify a pipeline version when running the pipeline on your data. This ensures that a specific version of the pipeline code and software are used when you run your pipeline. If you keep using the same tag, you'll be running the same version of the pipeline, even if there have been changes to the code since.

First, go to the [nf-core/hgtseq releases page](https://github.com/nf-core/hgtseq/releases) and find the latest pipeline version - numeric only (eg. `1.3.1`). Then specify this when running the pipeline with `-r` (one hyphen) - eg. `-r 1.3.1`. Of course, you can switch to another version by changing the number after the `-r` flag.

This version number will be logged in reports when you run the pipeline, so that you'll know what you used when you look back in the future. For example, at the bottom of the MultiQC reports.

To further assist in reproducbility, you can use share and re-use [parameter files](#running-the-pipeline) to repeat pipeline runs with the same settings without having to write out a command with every single parameter.

> 💡 If you wish to share such profile (such as upload as supplementary material for academic publications), make sure to NOT include cluster specific paths to files, nor institutional specific profiles.

## Pipeline arguments

> **NB:** These options are user-specific and use a _double_ hyphen.

Please note that, in addition to the classic parameters such as `--input` and `--outdir`, the pipeline requires other specific parameters.

### --genome

The user must specify the genome of interest. A list of genomes is available in the pipeline under the folder conf/igenomes.config, that contains illumina iGenomes reference file paths. This follows [nf-core guidelines](https://nf-co.re/usage/reference_genomes) for reference management, and sets all necessary parameters (like fasta, gtf, bwa). The user is recommended to primarily use the _genome_ parameter, and can follow instructions at [this](https://nf-co.re/usage/reference_genomes#adding-paths-to-a-config-file) page to add genomes not currently included in the repository. All parameters set automatically as a consequence, though hidden, can be accessed by the user at command line should they wish a finer control.

### --taxonomy_id

Since the code in the report is executed differently based on the taxonomy id of the analyzed species, the user must enter it in the command line (must be taken from the Taxonomy Database of NCBI).

### --krakendb

User must provide a Kraken2 database in order to perform the classification. Can optionally be in a `.tar.gz` archive.

### --kronadb

User must also provide a Krona database in order to generate interactive pie charts with Kronatools. Can optionally be in a `.tar.gz` archive.

## Core Nextflow arguments

> **NB:** These options are part of Nextflow and use a _single_ hyphen (pipeline parameters use a double-hyphen).

### `-profile`

Use this parameter to choose a configuration profile. Profiles can give configuration presets for different compute environments.

Several generic profiles are bundled with the pipeline which instruct the pipeline to use software packaged using different methods (Docker, Singularity, Podman, Shifter, Charliecloud, Apptainer, Conda) - see below.

> We highly recommend the use of Docker or Singularity containers for full pipeline reproducibility, however when this is not possible, Conda is also supported.

The pipeline also dynamically loads configurations from [https://github.com/nf-core/configs](https://github.com/nf-core/configs) when it runs, making multiple config profiles for various institutional clusters available at run time. For more information and to see if your system is available in these configs please see the [nf-core/configs documentation](https://github.com/nf-core/configs#documentation).

Note that multiple profiles can be loaded, for example: `-profile test,docker` - the order of arguments is important!
They are loaded in sequence, so later profiles can overwrite earlier profiles.

If `-profile` is not specified, the pipeline will run locally and expect all software to be installed and available on the `PATH`. This is _not_ recommended, since it can lead to different results on different machines dependent on the computer enviroment.

- `test`
  - A profile with a complete configuration for automated testing
  - Includes links to test data so needs no other parameters
- `docker`
  - A generic configuration profile to be used with [Docker](https://docker.com/)
- `singularity`
  - A generic configuration profile to be used with [Singularity](https://sylabs.io/docs/)
- `podman`
  - A generic configuration profile to be used with [Podman](https://podman.io/)
- `shifter`
  - A generic configuration profile to be used with [Shifter](https://nersc.gitlab.io/development/shifter/how-to-use/)
- `charliecloud`
  - A generic configuration profile to be used with [Charliecloud](https://hpc.github.io/charliecloud/)
- `apptainer`
  - A generic configuration profile to be used with [Apptainer](https://apptainer.org/)
- `conda`
  - A generic configuration profile to be used with [Conda](https://conda.io/docs/). Please only use Conda as a last resort i.e. when it's not possible to run the pipeline with Docker, Singularity, Podman, Shifter, Charliecloud, or Apptainer.

### `-resume`

Specify this when restarting a pipeline. Nextflow will use cached results from any pipeline steps where the inputs are the same, continuing from where it got to previously. For input to be considered the same, not only the names must be identical but the files' contents as well. For more info about this parameter, see [this blog post](https://www.nextflow.io/blog/2019/demystifying-nextflow-resume.html).

You can also supply a run name to resume a specific run: `-resume [run-name]`. Use the `nextflow log` command to show previous run names.

### `-c`

Specify the path to a specific config file (this is a core Nextflow command). See the [nf-core website documentation](https://nf-co.re/usage/configuration) for more information.

## Custom configuration

### Resource requests

Whilst the default requirements set within the pipeline will hopefully work for most people and with most input data, you may find that you want to customise the compute resources that the pipeline requests. Each step in the pipeline has a default set of requirements for number of CPUs, memory and time. For most of the steps in the pipeline, if the job exits with any of the error codes specified [here](https://github.com/nf-core/rnaseq/blob/4c27ef5610c87db00c3c5a3eed10b1d161abf575/conf/base.config#L18) it will automatically be resubmitted with higher requests (2 x original, then 3 x original). If it still fails after the third attempt then the pipeline execution is stopped.

To change the resource requests, please see the [max resources](https://nf-co.re/docs/usage/configuration#max-resources) and [tuning workflow resources](https://nf-co.re/docs/usage/configuration#tuning-workflow-resources) section of the nf-core website.

### Custom Containers

In some cases you may wish to change which container or conda environment a step of the pipeline uses for a particular tool. By default nf-core pipelines use containers and software from the [biocontainers](https://biocontainers.pro/) or [bioconda](https://bioconda.github.io/) projects. However in some cases the pipeline specified version maybe out of date.

To use a different container from the default container or conda environment specified in a pipeline, please see the [updating tool versions](https://nf-co.re/docs/usage/configuration#updating-tool-versions) section of the nf-core website.

### Custom Tool Arguments

A pipeline might not always support every possible argument or option of a particular tool used in pipeline. Fortunately, nf-core pipelines provide some freedom to users to insert additional parameters that the pipeline does not include by default.

To learn how to provide additional arguments to a particular tool of the pipeline, please see the [customising tool arguments](https://nf-co.re/docs/usage/configuration#customising-tool-arguments) section of the nf-core website.

### nf-core/configs

In most cases, you will only need to create a custom config as a one-off but if you and others within your organisation are likely to be running nf-core pipelines regularly and need to use the same settings regularly it may be a good idea to request that your custom config file is uploaded to the `nf-core/configs` git repository. Before you do this please can you test that the config file works with your pipeline of choice using the `-c` parameter. You can then create a pull request to the `nf-core/configs` repository with the addition of your config file, associated documentation file (see examples in [`nf-core/configs/docs`](https://github.com/nf-core/configs/tree/master/docs)), and amending [`nfcore_custom.config`](https://github.com/nf-core/configs/blob/master/nfcore_custom.config) to include your custom profile.

See the main [Nextflow documentation](https://www.nextflow.io/docs/latest/config.html) for more information about creating your own configuration files.

If you have any questions or issues please send us a message on [Slack](https://nf-co.re/join/slack) on the [`#configs` channel](https://nfcore.slack.com/channels/configs).

## Azure Resource Requests

To be used with the `azurebatch` profile by specifying the `-profile azurebatch`.
We recommend providing a compute `params.vm_type` of `Standard_D16_v3` VMs by default but these options can be changed if required.

Note that the choice of VM size depends on your quota and the overall workload during the analysis.
For a thorough list, please refer the [Azure Sizes for virtual machines in Azure](https://docs.microsoft.com/en-us/azure/virtual-machines/sizes).

## Running in the background

Nextflow handles job submissions and supervises the running jobs. The Nextflow process must run until the pipeline is finished.

The Nextflow `-bg` flag launches Nextflow in the background, detached from your terminal so that the workflow does not stop if you log out of your session. The logs are saved to a file.

Alternatively, you can use `screen` / `tmux` or similar tool to create a detached session which you can log back into at a later time.
Some HPC setups also allow you to run nextflow within a cluster job submitted your job scheduler (from where it submits more jobs).

## Nextflow memory requirements

In some cases, the Nextflow Java virtual machines can start to request a large amount of memory.
We recommend adding the following line to your environment to limit this (typically in `~/.bashrc` or `~./bash_profile`):

```bash
NXF_OPTS='-Xms1g -Xmx4g'
```

## Limitations

- Our local module `ranalysis` execute the circular plot in the html report only if human data is used (i.e. `--taxonomy_id 9606`, mandatory parameter explained above)
- If using `conda` as profile, hgtseq pipeline runs without executing `ranalysis` module due to a container conflict.
- `Kraken2` used for taxonomic classification requires lot of memory (~100GB). So we plan to implement `Clark` in a future release.
