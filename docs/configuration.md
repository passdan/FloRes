# Contents

* [Configuration](#configuration)
* [Customize environmental variables using profiles](#customize-environment-variables-using-profiles)
* [Customize parameters using the commandline](#customize-amr-pipeline-parameters)
  * [Modifying the params.config file](#modifying-the-paramsconfig-file) 
  * [Modifying parameters using the command-line](#modifying-parameters-using-the-command-line)
    * [Analyzing your samples](#analyzing-your-samples)
    * [Running with Kraken](#running-with-kraken)
    * [Including SNP confirmation](#running-with-snp-confirmation)
    * [Including deduplicated count results](#running-with-deduplicated-counts)
* [Selecting the right pipeline](#selecting-the-right-pipeline)

## Configuration
-------------

The pipeline source code comes with two configuration files that can be used to set environment variables and default command-line options. These configuration files can be found in the root source code directory and are called **nextflow.config** and **params.config**.

The **nextflow.config** file mainly contains parameters regarding how AMR++ will run on your computing cluster using the ```--profile``` parameter. 

The **params.config** contains parameters that control which files are being analyzed and parameters for the software in the pipeline. Setting the variables in the **params.config** before hand may be useful in situations when you do not want to specify a long list of options from the command line or want to have a seperate file for each project. You can modify these files, save the changes, and run the pipeline directly. More details below.


## Customize Environment Variables using profiles
----------------------------------------------

The **nextflow.config** contains a section that allows the use of environment "profiles" when running AmrPlusPlus. Further information for each profile can be found within the /config directory. In brief, profiles allow control over how the pipeline is run on different computing clusters. We recommend the "singularity" profile which employs singularity containers which contain all the required bioinformatic tools.

We make the following profiles available to suit your computing needs; "local", "local_slurm", "conda","conda_slurm", "singularity", "singularity_slurm", and "docker". You specify which profile to use with the ```-profile`` flag.


```bash
profiles {
  local {
    includeConfig "config/local.config"
  }
  local_slurm {
    includeConfig "config/local_slurm.config"
    process.executor = 'slurm'
  }
  conda {
    includeConfig "config/conda.config"
    conda.enabled = true
    conda.cacheDir = "${projectDir}/envs/"
    conda.useMamba = true
    conda.createTimeout = '30 min'
  }
  docker {
    includeConfig "config/local.config"
    docker.enabled = true
    process.container = 'enriquedoster/amrplusplus:latest'
  }
  singularity {
    includeConfig "config/singularity.config"
    singularity.enabled = true
    singularity.autoMounts = true
    singularity.cacheDir = "${projectDir}/envs/"
  }
  conda_slurm {
    includeConfig "config/conda_slurm.config"
    process.executor = 'slurm'
    conda.cacheDir = "${projectDir}/envs/"
    conda.enabled = true
    conda.useMamba = true
    conda.createTimeout = '30 min'
  }
   singularity_slurm {
    includeConfig "config/singularity_slurm.config"
    process.executor = 'slurm'
    singularity.enabled = true
    singularity.autoMounts = true
    singularity.cacheDir = "${projectDir}/envs/"
  }
}
```

## Customize AMR++ pipeline parameters
------------------------------

The params section allows you to set the different commmand-line options that can be used within the pipeline. Here, you can specify input/output options, trimming options, and algorithm options.

### Modifying the params.config file
Below is a list of all of the parameters that AMR++ uses by default. They can be found in the ```params.config``` file in the main directory. These parameters can be modified by changing this file or specifying any of these parameters on the command line using a double dash, like this: ```--reads "path/to/your/reads/*_R{1,2}.fastq.gz"```. Otherwise, change the parameters in the ```params.config``` file prior to running the AMR++ pipeline.

The authoritative list is `params.config` itself, which is commented throughout.
It is not reproduced here, because an inline copy drifts out of date.

The parameters fall into four groups:

| Group | Parameters |
|---|---|
| Input / output | `pipeline`, `reads`, `bam_files`, `split`, `output` |
| Reference data | `host`, `host_index`, `kraken_db`, `amr`, `amr_index`, `annotation`, `megares_lengths`, `multiqc` |
| Stage toggles | `fastqc`, `trim`, `host_removal`, `snp`, `deduped`, `kraken`, `bracken`, `normalise_to_length` |
| Analysis | `prefix`, `depth_basis`, `threshold`, `min`, `max`, `skip`, `samples`, `kraken_confidence_filter`, `kraken_confidence`, `readlen`, `taxlevel` |

Every toggle is a true/false value. Note that Nextflow 26.04's strict parser does
not coerce command line values, so the pipeline reads them through `as_bool()` in
`modules/functions.nf`; add any new boolean parameter the same way.

Per-process CPU and memory requests, and all error-handling policy, live in the
`process` block of `params.config` rather than in the process definitions.

### Modifying parameters using the command-line

#### Analyzing your samples
------
If you intend to run multiple samples in parallel, you must specify a glob pattern for your sequence data as shown for the **reads** parameter. For more information on globs, please see this related [article](https://en.wikipedia.org/wiki/Glob_(programming)).

For example, the default parameters can be used to run the pipeline with this command:

```bash
nextflow run . -profile singularity
```

This will run the default samples through the pipeline and this can be seen below, under the ```--reads``` parameter. To change the reads that were analyzed, you should specify the ```--reads`` parameter on the command line. Here, we can use regular expressions to point to your samples in a different directory.

```bash
nextflow run . -profile singularity  --reads "path/to/your/reads/*_R{1,2}.fastq.gz" 
```

#### Running with Kraken
-----
By default, the pipeline uses the default minikraken database (~4GB) to classify and assign taxonomic labels to your sequences. As Kraken loads this database into memory, this mini database is particularly useful for people who do not have access to large memory servers. We provide a script to easily download the minikraken database.

```bash
 bash scripts/download_minikraken.sh data/
 ```

If you would like to use a custom database or the standard Kraken database (~160GB), you will need to build it yourself and modify the **kraken_db** environment variable in the ```params.config ``` file to point to its location on your machine. 

#### Running with SNP confirmation
-----
To include SNP confirmation as part of the AMR++ analysis, you have to include the ```--snp true``` flag. Like this:

```bash
nextflow run . -profile singularity  --reads "path/to/your/reads/*_R{1,2}.fastq.gz" --snp true
```

#### Running with deduplicated counts
-----
Additionally, you can also output deduplicated counts by including the flag ```--deduped true```. Like this:

```bash
nextflow run . -profile singularity  --reads "path/to/your/reads/*_R{1,2}.fastq.gz" --snp true --deduped true
```


## Selecting the right pipeline

There is one main pipeline, `standard`, and stages are switched on and off with
parameters rather than by choosing a different pipeline.

```bash
# Everything: QC, trimming, host removal, resistome, Kraken, Bracken, normalisation
--pipeline standard

# Skip host removal (the old fast_AMR)
--pipeline standard --host_removal false

# Resistome only, no taxonomy (the old standard_AMR)
--pipeline standard --kraken false

# Kraken but not Bracken (the old standard_AMR_wKraken)
--pipeline standard --bracken false
```

Other entry points:

```bash
--pipeline bam      # resistome from existing BAMs, needs --bam_files
--pipeline hifi     # HiFi BAMs to FASTQ, then the standard pipeline
--pipeline qc       # FastQC and MultiQC only
--pipeline align    # Bowtie2 alignment to MEGARes only
--pipeline kraken   # Kraken2 and Bracken only
```

Stage toggles, all `true`/`false`: `--fastqc`, `--trim`, `--host_removal`,
`--snp`, `--deduped`, `--kraken`, `--bracken`, `--normalise_to_length`.

16S/QIIME 2 analysis and trimmomatic trimming have been removed.

