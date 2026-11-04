// Kraken2 classification and Bracken abundance re-estimation.

include { as_bool } from "${projectDir}/modules/functions.nf"

process dlkraken {
    tag "Download minikraken db"
    label "python"

    errorStrategy { task.exitStatus in 137..140 ? 'retry' : 'terminate' }
    maxRetries 3

    publishDir "${projectDir}/data/kraken_db/", mode: 'copy'

    output:
        path("minikraken_8GB_20200312/"), emit: krakendb

    script:
    """
    wget ftp://ftp.ccb.jhu.edu/pub/data/kraken2_dbs/minikraken_8GB_202003.tgz
    tar -xvzf minikraken_8GB_202003.tgz
    rm minikraken_8GB_202003.tgz
    """
}

process runkraken {
    tag { sample_id }
    label "microbiome"

    errorStrategy { task.exitStatus in 137..140 ? 'retry' : 'terminate' }
    maxRetries 3

    publishDir "${params.output}/MicrobiomeAnalysis", mode: 'copy',
        saveAs: { filename ->
            if( filename.endsWith(".kraken.filtered.report") ) "Kraken/filtered_report/$filename"
            else if( filename.endsWith(".kraken.filtered.raw") ) "Kraken/filtered/$filename"
            else if( filename.endsWith(".kraken.report") ) "Kraken/standard_report/$filename"
            else if( filename.endsWith(".kraken.raw") ) "Kraken/standard/$filename"
            else null
        }

    input:
        tuple val(sample_id), path(reads)
        path(krakendb)

    output:
        tuple val(sample_id), path("${sample_id}.kraken.raw"), emit: kraken_raw
        path("${sample_id}.kraken.report"), emit: kraken_report
        tuple val(sample_id), path("${sample_id}.kraken.report"), emit: bracken_input
        tuple val(sample_id), path("${sample_id}_kraken2.krona"), emit: krakenkrona
        tuple val(sample_id), path("${sample_id}.kraken.filtered.raw"), emit: kraken_filter_raw, optional: true
        path("${sample_id}.kraken.filtered.report"), emit: kraken_filter_report, optional: true
        tuple val(sample_id), path("${sample_id}_kraken2_filtered.krona"), emit: krakenkrona_filtered, optional: true

    script:
    def input_args = reads instanceof List && reads.size() > 1
        ? "--paired ${reads[0]} ${reads[1]}"
        : "${reads}"
    def filtered = as_bool(params.kraken_confidence_filter)
        ? """
          \${KRAKEN2:-kraken2} --db ${krakendb} --confidence ${params.kraken_confidence} ${input_args} \\
              --threads ${task.cpus} --report ${sample_id}.kraken.filtered.report > ${sample_id}.kraken.filtered.raw
          cut -f 2,3 ${sample_id}.kraken.filtered.raw > ${sample_id}_kraken2_filtered.krona
          """
        : ""
    """
    \${KRAKEN2:-kraken2} --db ${krakendb} ${input_args} \\
        --threads ${task.cpus} --report ${sample_id}.kraken.report > ${sample_id}.kraken.raw

    cut -f 2,3 ${sample_id}.kraken.raw > ${sample_id}_kraken2.krona
    ${filtered}
    """
}

process krakenresults {
    tag "Make Kraken count matrix"
    label "python"

    errorStrategy { task.exitStatus in 137..140 ? 'retry' : 'terminate' }
    maxRetries 3

    publishDir "${params.output}/Results/", mode: 'copy'

    input:
        path(kraken_reports)

    output:
        path("kraken_analytic_matrix.csv"), emit: kraken_matrix
        path("kraken_unclassifieds.csv"), emit: kraken_unclassifieds

    script:
    """
    \${PYTHON3:-python3} ${projectDir}/bin/kraken2_long_to_wide_update.py \\
        -i ${kraken_reports} -o kraken_analytic_matrix.csv
    """
}

process runbracken {
    tag { "${sample_id} ${level}" }
    label "microbiome"

    errorStrategy { task.exitStatus == 1 ? 'ignore' : 'terminate' }

    input:
        tuple val(sample_id), path(kraken_report), val(level)
        path(krakendb)

    output:
        tuple val("${level}"), path("${sample_id}_${level}.bracken.tsv"), emit: bracken_by_level

    script:
    """
    bracken \\
        -d ${krakendb} \\
        -r ${params.readlen} \\
        -i ${kraken_report} \\
        -l ${level} \\
        -o ${sample_id}_${level}.bracken.tsv
    """
}

process brackenresults {
    tag { level }
    label "python"

    errorStrategy { task.exitStatus in 137..140 ? 'retry' : 'terminate' }
    maxRetries 3

    publishDir "${params.output}/Results/Bracken", mode: 'copy'

    input:
        tuple val(level), path(bracken_reports)

    output:
        path("bracken_analytic_matrix_${level}.csv"), emit: bracken_matrix

    script:
    """
    combine_bracken_outputs.py --files ${bracken_reports} -o bracken_analytic_matrix_${level}.csv
    """
}
