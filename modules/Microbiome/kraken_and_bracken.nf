params.readlen = 150

threads = params.threads

process dlkraken {
    tag { }
    label "python"

    errorStrategy { task.exitStatus in 137..140 ? 'retry' : 'terminate' }
    maxRetries 3

    publishDir "$baseDir/data/kraken_db/", mode: 'copy'

    output:
        path("minikraken_8GB_20200312/")

    """
        echo "Attempting to download minikraken 8GB dataset"
        wget ftp://ftp.ccb.jhu.edu/pub/data/kraken2_dbs/minikraken_8GB_202003.tgz
        tar -xvzf minikraken_8GB_202003.tgz

    """
}


process runkraken {
    tag { sample_id }
    label "microbiome"

    errorStrategy { task.exitStatus in 137..140 ? 'retry' : 'terminate' }
    maxRetries 3

    publishDir "${params.output}/MicrobiomeAnalysis", mode: 'copy',
        saveAs: { filename ->
            if(filename.indexOf(".kraken.raw") > 0) "Kraken/standard/$filename"
            else if(filename.indexOf(".kraken.report") > 0) "Kraken/standard_report/$filename"
            else {}
        }

    input:
       tuple val(sample_id), path(reads)
       path(krakendb)


   output:
      tuple val(sample_id), path("${sample_id}.kraken.raw"), emit: kraken_raw
      path("${sample_id}.kraken.report"), emit: kraken_report
      tuple val(sample_id), path("${sample_id}.kraken.report"), emit: bracken_input
      tuple val(sample_id), path("${sample_id}_kraken2.krona"), emit: krakenkrona

     """
     ${KRAKEN2} --db ${krakendb} --paired ${reads[0]} ${reads[1]} --threads ${task.cpus} --report ${sample_id}.kraken.report > ${sample_id}.kraken.raw

     cut -f 2,3  ${sample_id}.kraken.raw > ${sample_id}_kraken2.krona
     """
}

process runkrakenInterleaved {
    tag { sample_id }
    label "microbiome"

    errorStrategy { task.exitStatus in 137..140 ? 'retry' : 'terminate' }
    maxRetries 3

    publishDir "${params.output}/MicrobiomeAnalysis", mode: 'copy',
        saveAs: { filename ->
            if(filename.indexOf(".kraken.raw") > 0) "Kraken/standard/$filename"
            else if(filename.indexOf(".kraken.report") > 0) "Kraken/standard_report/$filename"
            else {}
        }

    input:
       tuple val(sample_id), path(reads)
       path(krakendb)


   output:
      tuple val(sample_id), path("${sample_id}.kraken.raw"), emit: kraken_raw
      path("${sample_id}.kraken.report"), emit: kraken_report
      tuple val(sample_id), path("${sample_id}.kraken.report"), emit: bracken_input
      tuple val(sample_id), path("${sample_id}_kraken2.krona"), emit: krakenkrona

     """
     ${KRAKEN2} --db ${krakendb} --fastq-input ${reads} --threads ${task.cpus} --report ${sample_id}.kraken.report > ${sample_id}.kraken.raw

     cut -f 2,3  ${sample_id}.kraken.raw > ${sample_id}_kraken2.krona
     """
}

process krakenresults {
    tag { }
    label "python"

    errorStrategy { task.exitStatus in 137..140 ? 'retry' : 'terminate' }
    maxRetries 3

    publishDir "${params.output}/Results/", mode: 'copy'

    input:
        path(kraken_reports)

    output:
        path("kraken_analytic_matrix.csv")


    """
    ${PYTHON3} $baseDir/bin/kraken2_long_to_wide_update.py -i ${kraken_reports} -o kraken_analytic_matrix.csv
    """
}

process runbracken {
    label "microbiome"
    
    input:
       tuple val(sample_id), path(kraken_report), val(level)
       path(krakendb)

    output:
       tuple val("${level}"), path("${sample_id}_${level}.bracken.tsv"), emit: bracken_by_level

    """
    bracken \
   	-d ${krakendb} \
    -r ${params.readlen} \
	-i ${kraken_report} \
    -l $level \
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
        path("bracken_analytic_matrix_${level}.csv")

    """
    ${PYTHON3} /opt/conda/bin/combine_bracken_outputs.py --files ${bracken_reports} -o bracken_analytic_matrix_${level}.csv
    """
}

process kronadb {
    label "microbiome"
    output:
       file("krona_db/taxonomy.tab") optional true into krona_db_ch // is this a value ch?

    when: 
        !params.skip_krona
        
    script:
    """
    ktUpdateTaxonomy.sh krona_db
    """
}

process kronafromkraken {
    publishDir params.outdir, mode: 'copy'
    label "microbiome"
    input:
        file(x) from kraken2krona_ch.collect()
        //file(y) from kaiju2krona_ch.collect()
        file("krona_db/taxonomy.tab") from krona_db_ch
    
    output:
        file("*_taxonomy_krona.html")

    when:
        !params.skip_krona
    
    script:
    """
    mkdir krona
    ktImportTaxonomy -o kraken2_taxonomy_krona.html -tax krona_db $x
    """
}
