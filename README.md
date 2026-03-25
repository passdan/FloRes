Overview
--------
FloRes (Flow Resistome) is the Bangor University & Compass Bioinformatics developed version of the [AMR++ core repository](https://github.com/Microbial-Ecology-Group/AMRplusplus) with notable additions and modifications, and parameterised for running on different compute systems (including Super Computing Wales, Verily Workbench and Google Compute Cloud).

Notable changes to original pipeline:
- Additional integrated modules:
  - fastp
  - bowtie2 (host removal)
  - minimap2 (for longread data (Pacbio hifi/ONT))
  - bracken
  - R scripts for normalisation of amr tables
- Code changes and fixes
  - Reduce I/O for large data inputs
  - Work with new kraken2 taxonomy structure
  - Apptainer-slurm submission
  - Repair Nextflow channel bugs & version updates

  Note: Default alignment for megares is kept as BWA consistent with original AMR++ and can be changed by parameter. Bowtie2 alignment against megaresDB results in significant change on alignment rate.
---

# Preparing the install
1. Download the github repository with git clone and the url above

## Running with apptainer/singularity
2. The pipeline is configured to run with apptainer/singularity. If you are using this then no further installation preparation is required.
   You may choose to pre-build the singulariy images in advance if wanted. Note: config/singularity_slurm.conf is where singularity images can be defined.

## Reference databases
3. Optionally, download newer or more appropriate reference files
  ### bowtie2 index files to remove contamination/host DNA
  Either download directly, or build your indexes to be filtered against from user supplied fasta files. [Recommended] download human genome indexes directly from: https://bowtie-bio.sourceforge.net/bowtie2/index.shtml

  ### Kraken2 database
  The default parameter with AMR++ is to download the minikraken2 (2020) database which covers Bacteria, Archaea, Viruses which will occur the first time you run the pipeline.
  However you likely want a more updated version, and perhaps including fungi and plasmodium. They can be downloaded from here: https://benlangmead.github.io/aws-indexes/k2 and put in a location defined in the params.config file.

## Edit Slurm submission scripts
4. An example slurm script defines these parameters:
   - workdir:     Location where processing will be performed (advice: use high speed location on your processing node i.e. /tmp)
   - installdir:  Location of this github repo on your system
   - resultsdir:  Where do you want the main outputs to be transfered to (not the full working folders & outputs)
   - run:         Name of the sequencing run for annotation and folder where the fastq files are
                  Default input read location is: `$workdir/$run/fastq`
---

# Running the pipeline

Default pipeline is `standard_AMR_wKraken_and_bracken` which will run from raw fastqs to the endpoint. Alternatives are to use mid-process data, kraken only etc. by modifying the --pipeline parameter

    Core pipelines:
        - demo: Run a demonstration of AMR++
        - standard_AMR_wKraken: Run the standard AMR++ pipeline with Kraken
        - standard_AMR_wKraken_and_bracken: Run the standard AMR++ pipeline with Kraken AND Bracken
        - standard_hifi: Run the standard AMR++ pipeline for long-read (cleaned) data

    Available subworkflows:
        - eval_qc: Run FastQC analysis
        - trim_qc: Run trimming and quality control
        - rm_host: Remove host reads
        - resistome: Perform resistome analysis
        - align: Perform alignment to MEGARes database
        - kraken: Perform Kraken analysis
        - **NEW** kraken_and_bracken: Perform Kraken and Bracken analysis
        - qiime2: Perform QIIME 2 analysis
        - bam_resistome: Perform resistome analysis on BAM files

Submit as a slurm & singularity job with:
```
sbatch AMRplusplus_full.sh
```

You're finished!
