include { as_bool } from "${projectDir}/modules/functions.nf"

process SAMTOOLS_BAM2FQ {
    tag "$meta"
    label 'alignment'
    cpus 16


    input:
    tuple val(meta), path(inputbam)
    val split

    output:
    tuple val(meta), path("*.fq.gz"), emit: reads
    path "versions.yml"             , emit: versions

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta}"

    if( as_bool(split) ) {
        """
        samtools \\
            bam2fq \\
            $args \\
            -@ $task.cpus \\
            -1 ${prefix}_1.fq.gz \\
            -2 ${prefix}_2.fq.gz \\
            -0 ${prefix}_other.fq.gz \\
            -s ${prefix}_singleton.fq.gz \\
            $inputbam

        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            samtools: \$(echo \$(samtools --version 2>&1) | sed 's/^.*samtools //; s/Using.*\$//')
        END_VERSIONS
        """
    }
    else {
        """
        samtools \\
            bam2fq \\
            $args \\
            -@ ${task.cpus}  \\
            $inputbam | gzip --no-name > ${prefix}_interleaved.fq.gz

        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            samtools: \$(echo \$(samtools --version 2>&1) | sed 's/^.*samtools //; s/Using.*\$//')
        END_VERSIONS
        """
    }
}
