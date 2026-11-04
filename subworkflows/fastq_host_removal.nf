// Host read removal with bowtie2.

include { bowtie2_index ; bowtie2_rm_contaminant_fq ; HostRemovalStats } from "${projectDir}/modules/Alignment/bowtie2-for_AMRplusplus.nf"

workflow FASTQ_RM_HOST_WF {
    take:
        hostfasta
        read_pairs_ch

    main:
        if( params.host_index == null ) {
            bowtie2_index(hostfasta)
            reference_index_files = bowtie2_index.out.bowtie2index
        }
        else {
            def cached = file(params.host_index)
            def cached_files = cached instanceof List ? cached : [cached]
            if( cached_files.size() >= 6 && cached_files.every { entry -> entry.exists() } ) {
                reference_index_files = channel
                    .fromPath(params.host_index)
                    .toList()
                    .map { files -> files.sort() }
            }
            else {
                bowtie2_index(hostfasta)
                reference_index_files = bowtie2_index.out.bowtie2index
            }
        }

        bowtie2_rm_contaminant_fq(reference_index_files, read_pairs_ch)
        HostRemovalStats(bowtie2_rm_contaminant_fq.out.host_rm_stats.collect())

    emit:
        nonhost_reads = bowtie2_rm_contaminant_fq.out.nonhost_reads
}
