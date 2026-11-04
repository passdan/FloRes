Usage
-----

### Display Help Message

The `help` parameter displays the available options and commands.
```
nextflow run . --help
```

# Parameter selection
AMR++ comes with a default selection of parameters to perform a demonstration using example data provided in the "data/" directory. The example command below uses two types of parameters. 

```
nextflow run . -profile singularity --pipeline demo
```

The ```-profile``` parameter only has a single dash (```-```), meaning it corresponds to a nextflow-speific parameter and the  ```--pipeline```. Examples of parameters with one dash include ```-profile```, ```-resume```, and ```-config```. Further details on using the profile parameter, which determines how AMR++ runs on a computing cluster, can be found in the configuration document. Below, we'll see how to change the pipeline-specific parameters which are denoted using two dashes (```--```), such as ```--pipeline``` and ```--reads```.

The AMR++ pipeline pulls information from various sources to determine the correct parameters for running the pipeline. AMR++ is written in nextflow and this allows for us to change how the pipeline runs in a variety of ways. This is the order in which nextflow will prioritize parameters it receives.

1. Parameters specified on the command line (--something value)

2. Parameters provided using the -params-file option (params.config by default)

3. Config file specified using the -c my_config option (e.g. config/local.config)

4. The config file named nextflow.config in the current directory

5. The config file named nextflow.config in the workflow project directory

6. The config file $HOME/.nextflow/config

7. Values defined within the pipeline script itself (e.g. .)



## File Inputs

### Set custom sequence data

The `reads` parameter accepts sequence files in standard fastq and gz format.
```
$ nextflow run . --reads "data/raw/*_R{1,2}.fastq"
```

### Set host genome

The `host` parameter accepts a fasta formatted host genome.
```
$ nextflow run . --host "data/host/chr21.fasta.gz"
```

### Set MEGARes resistance database

The `amr` parameter accepts a fasta formatted resistance database. AMR++ is made to work with MEGARes databases and has to have the corresponding `--annotation` file in csv format.

```
$ nextflow run . --amr "data/amr/megares_database_v1.02.fasta"
```

### Set MEGARes annotation database

The `annotation` parameter accepts a csv formatted annotation database. Note, this must match the resistance database that was used above for the ResistomeAnalyzer and RarefactionAnalyzer steps to work correctly. 

```
$ nextflow run . --annotation "data/amr/megares_annotations_v1.02.csv"
```

### Adapters

Adapters are detected automatically by fastp (`--detect_adapter_for_pe`), so
there is no adapters parameter.

## File Outputs

### Set output and work directories

The `--output` parameter writes the results to the specified directory. As a nextflow variable, the `-work` parameter only requires one dash and determines where the temporary files will be directed. Upon completing the run, you can delete the temporary file directory.
```
$ nextflow run . --output "test/" -work "work_dir/"
```

## Resume a pipeline run

If the pipeline run is cancelled or stopped for whatever reason, using the same command with the addition of the `-resume` flag will attempt to pick up where the pipeline stopped. This "work" directory can take a lot of storage space and we recommend deleting it after completion of the pipeline.

```
$ nextflow run . --output "test/" -work "work_dir/" -resume
```

## Trimming Options

### Trimming

Trimming is done by fastp with automatic adapter detection and `--cut_right`
quality trimming. Trimmomatic has been removed, along with the `--leading`,
`--trailing`, `--minlen`, `--slidingwindow` and `--adapters` parameters.

Disable trimming entirely with `--trim false`.

## Algorithm Options

### Set custom ResistomeAnalyzer algorithm options

```
$ nextflow run . \
    --reads "data/raw/*_R{1,2}.fastq" \
    --threshold 80 \
    --min 1 \
    --max 100 \
    --samples 5 \
    --skip 5 \
    --output "test/"
```

## Set CPUs per process

The `--threads` parameter has been removed. Processes use `task.cpus`, set per
process in `params.config` or your profile config:

```
process {
    withName: 'runkraken' {
        cpus = 16
        memory = "245.GB"
    }
}
```


## Run AMR++ with SLURM

Adding the ```-bg``` flag submits AMR++ to the SLURM queue and when combined with a "slurm" profile, jobs will be submitted for each individual process in the pipeline.

```
nextflow run . -profile local_slurm --snp true -bg > bg-log.out
```