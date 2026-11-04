// FastQC and MultiQC read reporting.

include { fastqc ; multiqc } from '../modules/Fastqc/fastqc.nf'

workflow FASTQ_QC_WF {
    take:
    read_pairs_ch
    multiqc_config

    main:
    fastqc(read_pairs_ch)
    multiqc(fastqc.out.logs.collect(), multiqc_config)
}
