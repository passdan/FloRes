// Read trimming and adapter removal with fastp.

process runqc {
    tag { sample_id }
    label 'trimming'

    publishDir "${params.output}/QC_analysis/fastp", mode: 'copy', saveAs: { filename -> filename.endsWith('.log') ? filename : null }

    input:
    tuple val(sample_id), path(reads)

    output:
    tuple val(sample_id), path("${sample_id}*P.fastq.gz"), emit: paired_fastq
    path ("${sample_id}.fastp.log"), emit: fastp_stats

    script:
    """
    \${FASTP:-fastp} \\
        --in1 ${reads[0]} \\
        --in2 ${reads[1]} \\
        --out1 ${sample_id}.1P.fastq.gz \\
        --out2 ${sample_id}.2P.fastq.gz \\
        --json ${sample_id}.fastp.json \\
        --html ${sample_id}.fastp.html \\
        --thread ${task.cpus} \\
        --detect_adapter_for_pe \\
        --trim_poly_g \\
        --cut_right \\
        2> ${sample_id}.fastp.log
    """
}
