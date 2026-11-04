// Kraken2 classification, optionally followed by Bracken.

include { runkraken ; krakenresults ; runbracken ; brackenresults ; dlkraken } from '../modules/Microbiome/kraken_and_bracken.nf'
include { as_bool } from '../modules/functions.nf'

workflow FASTQ_MICROBIOME_WF {
    take:
    reads_ch
    krakendb
    taxlevel_ch

    main:
    if (krakendb == null) {
        def cached = file("${projectDir}/data/kraken_db/minikraken_8GB_20200312/")
        if (cached.isDirectory()) {
            kraken_db_ch = channel.fromPath(cached)
        }
        else {
            dlkraken()
            kraken_db_ch = dlkraken.out.krakendb
        }
    }
    else {
        kraken_db_ch = channel.fromPath(krakendb)
    }

    runkraken(reads_ch, kraken_db_ch.first())
    krakenresults(runkraken.out.kraken_report.collect())

    bracken_matrix_ch = channel.empty()
    if (as_bool(params.bracken)) {
        bracken_input_ch = runkraken.out.bracken_input.combine(taxlevel_ch)
        runbracken(bracken_input_ch, kraken_db_ch.first())

        grouped_bracken_ch = runbracken.out.bracken_by_level.groupTuple()
        brackenresults(grouped_bracken_ch)
        bracken_matrix_ch = brackenresults.out.bracken_matrix
    }

    emit:
    kraken_matrix = krakenresults.out.kraken_matrix
    kraken_unclassifieds = krakenresults.out.kraken_unclassifieds
    bracken_matrix = bracken_matrix_ch
}
