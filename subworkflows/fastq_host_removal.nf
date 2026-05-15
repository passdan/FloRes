// Load modules
//include { index } from '../modules/Alignment/bwa'
//include { bwa_align ; bwa_rm_contaminant_fq ; HostRemovalStats} from '../modules/Alignment/bwa'

include { bowtie2_index } from '../modules/Alignment/bowtie2-for_AMRplusplus'
include { bowtie2_align ; bowtie2_rm_contaminant_fq ; HostRemovalStats} from '../modules/Alignment/bowtie2-for_AMRplusplus'

import java.nio.file.Paths

// WC trimming
workflow FASTQ_RM_HOST_WF {
    take: 
        hostfasta
        read_pairs_ch
    main:
        // Define reference_index variable
        if (params.host_index == null) {
            bowtie2_index(hostfasta)
            reference_index_files = bowtie2_index.out
        } else {
            reference_index_files = Channel
               .fromPath(params.host_index)
               .toList()
               .map { files ->
                   if (files.size() < 6) {
                       error "Expected 6 host index files, found ${files.size()}. Please provide all 6 files, including the host fasta file. Remember to use * in your path."
                   } else {
                       files.sort()
                   }
               }
         }    

        bowtie2_rm_contaminant_fq(reference_index_files, read_pairs_ch )
        HostRemovalStats(bowtie2_rm_contaminant_fq.out.host_rm_stats.collect())
    emit:
        nonhost_reads = bowtie2_rm_contaminant_fq.out.nonhost_reads  
}
