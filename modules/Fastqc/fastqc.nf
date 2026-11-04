// Read quality reporting with FastQC and MultiQC.

process fastqc {
    tag "FASTQC on ${sample_id}"
    label "fastqc"

    publishDir "${params.output}/QC_analysis/FastQC", mode: 'copy'

    input:
    tuple val(sample_id), path(reads)

    output:
    path ("${sample_id}_fastqc_logs"), emit: logs

    script:
    """
    mkdir ${sample_id}_fastqc_logs
    fastqc -o ${sample_id}_fastqc_logs -f fastq -q ${reads}
    """
}

process multiqc {
    tag "Running multiQC"
    label "fastqc"

    publishDir "${params.output}/QC_analysis/MultiQC_stats", mode: 'copy'

    input:
    path 'data*/*'
    path config

    output:
    path 'multiqc_report.html', emit: report
    path 'multiqc_general_stats.txt', emit: general_stats
    path 'multiqc_data/', emit: data

    script:
    """
    cp ${config}/* .
    multiqc -v data* --interactive -f --cl-config "max_table_rows: 3000" --outdir multiqc_data --filename multiqc_report.html
    mv multiqc_data/multiqc_report_data/multiqc_general_stats.txt .
    mv multiqc_data/multiqc_report.html .
    """
}
