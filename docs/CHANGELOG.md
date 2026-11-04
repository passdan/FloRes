Details on AMR++ updates
------------

## 2026-11-04 : FloRes cleanup and Nextflow 26.04

### Nextflow 26.04 / strict syntax
- Migrated to the strict syntax parser, which is the default from 26.04. Full
  detail in `docs/nextflow-26-migration.md`. Requires Java 17 or newer.
- Boolean parameters must now be read through `as_bool()` in
  `modules/functions.nf`: the strict parser does not coerce command line values,
  so `--kraken false` arrives as the truthy string `"false"`.

### Pipeline consolidation
- One `standard` pipeline replaces `demo`, `fast_AMR`, `standard_AMR`,
  `standard_AMR_wKraken` and `standard_AMR_wKraken_and_Bracken`. Stages are
  switched with `--fastqc`, `--trim`, `--host_removal`, `--snp`, `--deduped`,
  `--kraken`, `--bracken` and `--normalise_to_length`.
- `--pipeline` values went from 15 to 6: `standard`, `bam`, `hifi`, `qc`,
  `align`, `kraken`. Retired names error out naming their replacement flags.
- Boolean parameters changed from `"Y"`/`"N"` to `true`/`false`.
- Subworkflows went from 17 to 8, modules from 12 to 8. The three near-duplicate
  resistome subworkflows became one `RESISTOME_WF` taking an output prefix, which
  also removed the `addParams` include that strict syntax rejects.
- `hifi` is now BAM-to-FASTQ feeding the standard pipeline rather than a separate
  workflow. The interleaved Kraken subworkflow merged into `runkraken`.

### Length normalisation
- New `normalise_matrix` process producing RPKM-normalised count matrices for
  both the standard and SNP-confirmed matrices, via `bin/normalise_to_length.py`.
- `--depth_basis classified|total` chooses the denominator. `classified` (default)
  uses the Kraken matrix column sums; `total` adds unclassified reads from
  `kraken_unclassifieds.csv`. Values are not comparable between the two.
- `--megares_lengths` points at the gene lengths table, added at
  `data/amr/megares_lengths.txt`.

### Removed
- Trimmomatic. fastp has done the trimming for some time and the trimmomatic path
  was already commented out. The `--adapters`, `--leading`, `--trailing`,
  `--minlen` and `--slidingwindow` parameters are gone with it.
- QIIME 2 / 16S support, including `data/Test_16S_data` and the dada2 parameters.
- `--threads`. Processes use `task.cpus`, set per process in config.
- `modules/Microbiome/kraken2.nf`, a dead duplicate that did not parse, and its
  `bin/kraken2_long_to_wide.py`.
- `modules/Alignment/minimap2.nf`, `modules/nf-functions.nf`,
  `config/old_singularity_slurm.config` and four unreferenced conda env files.
- Bowtie2 deduplication, which only ever printed "not implemented" and had Groovy
  comments inside a bash block.

### Fixed
- `main.nf` reported missing input whenever input was provided: the condition was
  inverted and used a single `|`.
- `bwa_align`'s dedup branch wrote and deleted an unused SAM and used the
  deprecated `samtools rmdup`. Rewritten around `samtools markdup`. **Deduplicated
  counts will differ slightly from previous runs.**
- `runkrakenInterleaved` passed `--fastq-input`, a Kraken 1 flag.
- `multiqc`'s `publishDir` tested for `multiqc_data/*`, which never matched, so
  that output was declared but never published.
- `SAMTOOLS_BAM2FQ` in split mode emitted unpaired and singleton reads into the
  same glob as the paired output; they now go to `/dev/null`.
- The `google-batch` profile interpolated environment variables directly, which
  broke any run outside GCP because Nextflow parses every profile. It also set
  `refDir` rather than `params.refDir`, so that value was silently ignored.
- `.gitattributes` added. A Windows clone produced CRLF endings, which made every
  `bin/` script unexecutable via its shebang once called directly.
- The SLURM submit scripts in `scripts/` used retired pipeline names, `--snp Y`,
  a `--resume` typo and a pinned 24.10 binary.
- `wb/run.sh` invoked `main_AMRplusplus.nf`, which has never existed in this
  repository, and passed the retired `standard_AMR_wKraken_and_Bracken`.
- `bin/snp_long_to_wide.py` had CRLF line endings committed in the index, so on a
  fresh Linux clone its shebang resolved to `python3\r` and `--snp true` would
  have failed at the final step.
- `docs/configuration.md` embedded a stale copy of `params.config` listing
  parameters that no longer exist (`reference`, `snp_confirmation`, `threads`,
  the trimmomatic set). Replaced with a grouped summary that points at the file.
- `docs/dependencies.md` still listed Trimmomatic; now lists fastp and Bowtie2,
  and marks Bracken as required rather than optional since `--bracken` defaults
  to true.

### Consistency
- All error handling moved from the 22 per-process directives into `params.config`,
  where config precedence means it would have won anyway.
- Resource requests moved out of process bodies into config.
- `index` renamed `bwa_index`, for symmetry with `bowtie2_index`.
- Manual helper scripts moved from `bin/` to `scripts/`. Nextflow stages `bin/`
  onto every task's PATH, so only pipeline scripts belong there.
- Every module and subworkflow now opens with a comment saying what it does.

## 2022-09-06 : AMR++ v3 update
- Change in repository from [AMR++ v2](https://github.com/meglab-metagenomics/amrplusplus_v2) to this repository under the [microbial ecology group github page](https://github.com/Microbial-Ecology-Group/AMRplusplus). This repository will include all further updates to AMR++. 
- Addition of [SNP confirmation software](https://github.com/Isabella136/AmrPlusPlus_SNP)
- pipeline structure
   - switch to nextflow DSL2 and collection of "pipeline" options
   - snakemake approach for optimizing storage requirements
- Includes updates to MEGARes v3


## 2020-05-21 : AMR++ v2.0.2 update
Fixed a mistake with the config/singularity.config file to correctly call the singularity container anytime that RGI is run.

## 2020-05-21 : AMR++ v2.0.1 update
We identified issues with running RGI thanks to github users, AroArz and DiegoBrambilla. As of this update, RGI developers are focused on contributing to the COVID-19 response, so we plan to reconvene with them when their schedule opens up. In the meantime, we are releasing updates to continue AMR++ functionality.
We found that the errors were associated with RGI bugs that were previously reported:
* In [RGI issue #93](https://github.com/arpcard/rgi/issues/93), the github user, mahesh-panchal, reported that you need to run the "rgi main" command twice on the same dataset for it to successfully complete the analysis. The RGI component of AMR++ has been updated to work for now, but we plan for further changes to clean up the code.
* In [RGI issue #60](https://github.com/arpcard/rgi/issues/60), caspargross reported issues with containerizing RGI due to requirements for a "writable file system". As a temporary fix, we updated AMR++ code so that the user has to download the CARD database locally and use an additional flag to specify the location of the local database.
* Errors in running RGI will now be "ignored" so that the pipeline continues running but still provides any temporary files created with RGI. This should allow you to troubleshoot on your own or run any additional analysis using the reads aligning to gene accessions that "RequireSNPConfirmation"

Other updates:
* minor fixes to singularity/slurm configuration files
* updated the "resistome" and "rarefaction" code. It is now included in the "bin" directory.
* updated the script for downloading the latest version of mini-kraken
* created new singularity container just for the RGI software
* output zipped nonhost files directly
