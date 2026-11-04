// The AMR++ pipeline. Every stage is controlled by a parameter, so this one
// workflow replaces the former standard / fast / wKraken / wKrak_and_Brack set.

include { FASTQ_QC_WF }        from "${projectDir}/subworkflows/fastq_information.nf"
include { FASTQ_TRIM_WF }      from "${projectDir}/subworkflows/fastq_QC_trimming.nf"
include { FASTQ_RM_HOST_WF }   from "${projectDir}/subworkflows/fastq_host_removal.nf"
include { FASTQ_RESISTOME_WF } from "${projectDir}/subworkflows/fastq_resistome.nf"
include { FASTQ_MICROBIOME_WF } from "${projectDir}/subworkflows/fastq_microbiome.nf"
include { normalise_matrix }   from "${projectDir}/modules/Resistome/resistome.nf"
include { as_bool ; check_file } from "${projectDir}/modules/functions.nf"

workflow AMRPLUSPLUS {
    take:
        read_pairs_ch
        hostfasta
        amr
        annotation
        krakendb
        taxlevel_ch

    main:
        if( as_bool(params.fastqc) )
            FASTQ_QC_WF(read_pairs_ch, params.multiqc)

        if( as_bool(params.trim) ) {
            FASTQ_TRIM_WF(read_pairs_ch)
            qc_reads_ch = FASTQ_TRIM_WF.out.trimmed_reads
        }
        else {
            qc_reads_ch = read_pairs_ch
        }

        if( as_bool(params.host_removal) ) {
            FASTQ_RM_HOST_WF(hostfasta, qc_reads_ch)
            clean_reads_ch = FASTQ_RM_HOST_WF.out.nonhost_reads
        }
        else {
            clean_reads_ch = qc_reads_ch
        }

        FASTQ_RESISTOME_WF(clean_reads_ch, amr, annotation)

        if( as_bool(params.kraken) ) {
            FASTQ_MICROBIOME_WF(clean_reads_ch, krakendb, taxlevel_ch)

            if( as_bool(params.normalise_to_length) ) {
                gene_lengths = check_file(params.megares_lengths, 'megares_lengths')
                count_matrices_ch = FASTQ_RESISTOME_WF.out.raw_count_matrix
                    .mix(FASTQ_RESISTOME_WF.out.snp_matrix)
                normalise_matrix(
                    count_matrices_ch,
                    FASTQ_MICROBIOME_WF.out.kraken_matrix.first(),
                    FASTQ_MICROBIOME_WF.out.kraken_unclassifieds.first(),
                    gene_lengths
                )
            }
        }
        else if( as_bool(params.normalise_to_length) ) {
            log.warn "Skipping length normalisation: it needs the Kraken count matrix for sequencing depth, but --kraken is false."
        }
}
