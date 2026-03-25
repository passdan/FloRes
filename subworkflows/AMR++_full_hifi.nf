include { FASTQ_QC_WF } from "$baseDir/subworkflows/fastq_information.nf"
include { SAMTOOLS_BAM2FQ } from "$baseDir/modules/Tools/bam2fq.nf"
include { FASTQ_TRIM_WF } from "$baseDir/subworkflows/fastq_QC_trimming.nf"
include { FASTQ_RM_HOST_WF } from "$baseDir/subworkflows/fastq_host_removal.nf" 
//include { FASTQ_RESISTOME_WF_BWA } from "$baseDir/subworkflows/fastq_resistome_bwa.nf"
include { FASTQ_KRAKEN_AND_BRACKEN_WF } from "$baseDir/subworkflows/fastq_microbiome_wBracken_interleaved.nf"

workflow STANDARD_full_hifi {
    take: 
        bam_in_ch
        hostfasta
        amr
        annotation
        krakendb
	taxlevel_ch
	split

    main:
	// bam2fq
	SAMTOOLS_BAM2FQ( bam_in_ch, params.split )
        // fastqc
        //FASTQ_QC_WF( read_pairs_ch )
        // runqc trimming
        //FASTQ_TRIM_WF(read_pairs_ch)
        // remove host DNA
        //FASTQ_RM_HOST_WF(hostfasta, FASTQ_TRIM_WF.out.trimmed_reads)
        // AMR alignment
        //FASTQ_RESISTOME_WF_BWA(FASTQ_RM_HOST_WF.out.nonhost_reads, amr, annotation)
        // Microbiome
        FASTQ_KRAKEN_AND_BRACKEN_WF(SAMTOOLS_BAM2FQ.out.reads, params.kraken_db, taxlevel_ch)


}
