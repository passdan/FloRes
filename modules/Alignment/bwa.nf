// BWA-MEM indexing and alignment.

include { as_bool } from "${projectDir}/modules/functions.nf"

process index {
    tag "Creating bwa index"
    label "alignment"

    errorStrategy { task.exitStatus in 137..140 ? 'retry' : 'terminate' }
    maxRetries 3

    publishDir "${params.output}/Alignment/BWA_Index", mode: "copy"

    input:
        path fasta

    output:
        path("${fasta}*"), emit: bwaindex, includeInputs: true

    script:
    """
    \${BWA:-bwa} index ${fasta}
    """
}

process bwa_align {
    tag "$pair_id"
    label "alignment"

    errorStrategy { task.exitStatus in 137..140 ? 'retry' : 'terminate' }
    maxRetries 3

    publishDir "${params.output}/Alignment/BAM_files", mode: "copy",
        saveAs: { filename ->
            if( filename.endsWith("_alignment_sorted.bam") ) "Standard/$filename"
            else if( filename.endsWith("_alignment_dedup.bam") ) "Deduped/$filename"
            else null
        }

    input:
        path indexfiles
        tuple val(pair_id), path(reads)

    output:
        tuple val(pair_id), path("${pair_id}_alignment_sorted.bam"), emit: bwa_bam
        tuple val(pair_id), path("${pair_id}_alignment_dedup.bam"), emit: bwa_dedup_bam, optional: true

    script:
    if( !as_bool(params.deduped) )
        """
        \${BWA:-bwa} mem ${indexfiles[0]} ${reads} -t ${task.cpus} -R '@RG\\tID:${pair_id}\\tSM:${pair_id}' | \\
            \${SAMTOOLS:-samtools} sort -@ ${task.cpus} -m 4G -o ${pair_id}_alignment_sorted.bam
        """
    else
        """
        \${BWA:-bwa} mem ${indexfiles[0]} ${reads} -t ${task.cpus} -R '@RG\\tID:${pair_id}\\tSM:${pair_id}' | \\
            \${SAMTOOLS:-samtools} sort -n -@ ${task.cpus} -m 3G -o ${pair_id}_alignment_namesorted.bam

        \${SAMTOOLS:-samtools} fixmate -@ ${task.cpus} ${pair_id}_alignment_namesorted.bam ${pair_id}_alignment_fix.bam
        rm ${pair_id}_alignment_namesorted.bam

        \${SAMTOOLS:-samtools} sort -@ ${task.cpus} -m 3G ${pair_id}_alignment_fix.bam -o ${pair_id}_alignment_sorted.bam
        rm ${pair_id}_alignment_fix.bam

        \${SAMTOOLS:-samtools} markdup -r -@ ${task.cpus} ${pair_id}_alignment_sorted.bam ${pair_id}_alignment_dedup.bam
        """
}
