// Read trimming with fastp.

include { runqc } from "${projectDir}/modules/Trimming/fastp.nf"

workflow FASTQ_TRIM_WF {
    take:
        read_pairs_ch

    main:
        runqc(read_pairs_ch)

    emit:
        trimmed_reads = runqc.out.paired_fastq
        fastp_stats   = runqc.out.fastp_stats
}
