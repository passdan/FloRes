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

## Containers
2. The pipeline is configured to run either with apptainer/singularity locally with automatic container download, or with docker if using google-batch remotely. You may choose to pre-build the singulariy images in advance if wanted (containers defined in conf/ folder)
Note: If you are using Workbench/batch then you must pre-build the docker containers locally and upload to the container repository with the google CLI sdk.

## Reference databases
3. Default downloads are performed on first run but you will likely want to download newer or more appropriate reference files
  ### bowtie2 index files to remove contamination/host DNA
  Either download directly, or build your indexes to be filtered against from user supplied fasta files. [Recommended] download human genome indexes directly from: https://bowtie-bio.sourceforge.net/bowtie2/index.shtml

  ### Kraken2 database
  The default parameter with AMR++ is to download the minikraken2 (2020) database which covers Bacteria, Archaea, Viruses which will occur the first time you run the pipeline.
  However you likely want a more updated version, and perhaps including fungi and plasmodium. They can be downloaded from here: https://benlangmead.github.io/aws-indexes/k2 and put in a location defined in the params.config file.

## Slurm submission scripts if required
4. An example slurm script defines these parameters:
   - workdir:     Location where processing will be performed (advice: use high speed location on your processing node i.e. /tmp)
   - installdir:  Location of this github repo on your system
   - resultsdir:  Where do you want the main outputs to be transfered to (not the full working folders & outputs)
   - run:         Name of the sequencing run for annotation and folder where the fastq files are
                  Default input read location is: `$workdir/$run/fastq`
---

# Running the pipeline

The default pipeline is `standard`, which runs from raw fastqs through to
normalised count matrices. Stages are switched on and off with parameters rather
than by choosing a different pipeline.

    Pipelines (--pipeline, default: standard)
        - standard   Full pipeline: QC, trimming, host removal, resistome,
                     Kraken, Bracken and length normalisation
        - bam        Resistome quantification from existing BAMs (--bam_files)
        - hifi       HiFi BAMs to FASTQ (--bam_files), then the standard pipeline
        - qc         FastQC and MultiQC only
        - align      Bowtie2 alignment to MEGARes only
        - kraken     Kraken2 (and Bracken) classification only

    Stage toggles (all true/false)
        --fastqc              FastQC and MultiQC               (default: true)
        --trim                fastp trimming                   (default: true)
        --host_removal        Host read removal with bowtie2   (default: true)
        --snp                 SNP confirmation                 (default: true)
        --deduped             Also produce deduplicated counts (default: false)
        --kraken              Kraken2 classification           (default: true)
        --bracken             Bracken after Kraken2            (default: true)
        --normalise_to_length Normalise to gene length and depth (default: true)

    Normalisation
        --depth_basis         classified | total               (default: classified)
        --megares_lengths     Gene lengths table (gene_accession<TAB>bp)

So the old `standard_AMR_wKraken` is now `--pipeline standard --bracken false`,
and `fast_AMR` is `--pipeline standard --host_removal false`. The old
`--pipeline` names error out with the replacement flags; see
`docs/nextflow-26-migration.md`.

16S/QIIME 2 support and trimmomatic have been removed. Trimming has been done by
fastp for some time; the trimmomatic code path was already commented out.

This pipeline targets Nextflow 26.04 and its strict syntax parser. Java 17 or
newer is required.

You're finished!
