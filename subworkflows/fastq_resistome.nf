// BWA alignment to MEGARes followed by resistome quantification.

include { index ; bwa_align } from "${projectDir}/modules/Alignment/bwa.nf"
include { RESISTOME_WF } from "${projectDir}/subworkflows/resistome.nf"
include { RESISTOME_WF as RESISTOME_DEDUP_WF } from "${projectDir}/subworkflows/resistome.nf"
include { as_bool } from "${projectDir}/modules/functions.nf"

workflow FASTQ_RESISTOME_WF {
    take:
        read_pairs_ch
        amr
        annotation

    main:
        if( params.amr_index == null ) {
            index(amr)
            amr_index_files = index.out.bwaindex
        }
        else {
            amr_index_files = channel
                .fromPath(params.amr_index)
                .filter { entry -> entry.exists() }
                .toList()
                .map { files ->
                    if( files.size() < 6 )
                        error "Expected 6 AMR index files, found ${files.size()}. Provide all 6 files, including the AMR database fasta. Remember to use * in your path."
                    files.sort()
                }
        }

        bwa_align(amr_index_files, read_pairs_ch)

        RESISTOME_WF(bwa_align.out.bwa_bam, amr, annotation, params.prefix, true)

        if( as_bool(params.deduped) )
            RESISTOME_DEDUP_WF(bwa_align.out.bwa_dedup_bam, amr, annotation, "dedup_${params.prefix}", false)

    emit:
        raw_count_matrix = RESISTOME_WF.out.raw_count_matrix
        snp_matrix       = RESISTOME_WF.out.snp_matrix
}
