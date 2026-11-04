// Bowtie2 alignment to MEGARes only, without resistome quantification.

include { bowtie2_index ; bowtie2_align } from "${projectDir}/modules/Alignment/bowtie2-for_AMRplusplus.nf"

workflow FASTQ_ALIGN_WF {
    take:
        read_pairs_ch
        amr

    main:
        if( params.amr_index == null ) {
            bowtie2_index(amr)
            amr_index_files = bowtie2_index.out.bowtie2index
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

        bowtie2_align(amr_index_files, read_pairs_ch)

    emit:
        bam = bowtie2_align.out.bowtie2_bam
}
