Dependencies
------------

AMR++ uses a variety of open-source tools. The tools used, descriptions, and version specifics are provided below. These dependencies can be installed manually to your local computing cluster, or by changing the ```-profile``` parameter, they can be handled using conda, sigularity, or docker.

### fastp
  - Description: An all-in-one FASTQ preprocessor for quality filtering, adapter trimming and quality pruning. Replaced Trimmomatic.
  - DOI: https://doi.org/10.1093/bioinformatics/bty560

### FastQC
  - Description: A quality control tool for high throughput sequence data.
  - Version: 0.11.8

### multiQC
  - Description: Create aggregate bioinformatics analysis reports across many samples and tools
  - Version: 1.6
  - DOI: https://doi.org/10.1093/bioinformatics/btw354

### Bedtools
  - Description: Bedtools is a suite of tools that can be used to compute and extract useful information from BAM, BED, and BCF files.
  - Version: 2.28.0
  - DOI: https://doi.org/10.1093/bioinformatics/btq033

### BWA
  - Description: BWA is a short and long read sequence aligner for aligning raw sequence data to a reference genome.
  - Version: 0.7.17
  - DOI: https://doi.org/10.1093/bioinformatics/btp324

### Bowtie2
  - Description: Bowtie2 is a fast and memory-efficient read aligner, used here for host read removal and as an alternative MEGARes aligner.
  - DOI: https://doi.org/10.1038/nmeth.1923

### Kraken2
  - Description: Kraken is a fast taxonomic sequence classifier that assigns taxonomy labels to short-reads.
  - Version: 2.0.8
  - DOI: https://doi.org/10.1186/gb-2014-15-3-r46

### RarefactionAnalyzer
  - Description: RarefactionAnalyzer is a tool that can be used for performing rarefaction analysis.
  - Version: 0.0.0
  - DOI: https://doi.org/10.1093/nar/gkw1009

### ResistomeAnalyzer
  - Description: ResistomeAnalyzer is a tool for analyzing the resistome of large metagenomic datasets.
  - Version: 0.0.0
  - DOI: https://doi.org/10.1093/nar/gkw1009
  
### Samtools
  - Description: Samtools is a program for manipulating and extracting useful information from alignment files in SAM or BAM format.
  - Version: 1.9
  - DOI: https://doi.org/10.1093/bioinformatics/btp352

### AmrPlusPlus_SNP
  - Description: The [AMRPlusPlus_SNP repository](https://github.com/Isabella136/AmrPlusPlus_SNP) contains multiple progams used to either extract SNP info or to verify ARGs for resistant-conferring SNPs. 
  - Version: 0.0.0
  - DOI: 

### Bracken
  - Description: Bracken (Bayesian Reestimation of Abundance with KrakEN) is a highly accurate statistical method that computes the abundance of species in DNA sequences from a metagenomics sample.
  - Version: 2.7
  - DOI: 10.7717/peerj-cs.104
  - Note: required when `--bracken true`, which is the default. Also provides `combine_bracken_outputs.py`.

# Optional software

### Krona
  - Description: Krona Tools is a set of scripts to create Krona charts from several Bioinformatics tools as well as from text and XML files.
  - Version: 2.8.1
  - DOI: https://doi.org/10.1186/1471-2105-12-385

  
