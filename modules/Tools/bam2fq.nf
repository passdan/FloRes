// Convert BAM alignments back to FASTQ.

include { as_bool } from '../functions.nf'

process SAMTOOLS_BAM2FQ {
    tag { sample_id }
    label 'alignment'

    publishDir "${params.output}/Bam2Fastq", mode: 'copy'

    input:
    tuple val(sample_id), path(inputbam)
    val split

    output:
    tuple val(sample_id), path("*.fq.gz"), emit: reads

    script:
    if (as_bool(split)) {
        // Unpaired and singleton reads go to /dev/null so that the output glob
        // picks up only the two paired files.
        """
        \${SAMTOOLS:-samtools} bam2fq \\
            -@ ${task.cpus} \\
            -1 ${sample_id}_1.fq.gz \\
            -2 ${sample_id}_2.fq.gz \\
            -0 /dev/null \\
            -s /dev/null \\
            -n \\
            ${inputbam}
        """
    }
    else {
        """
        \${SAMTOOLS:-samtools} bam2fq -@ ${task.cpus} ${inputbam} \\
            | gzip --no-name > ${sample_id}_interleaved.fq.gz
        """
    }
}
