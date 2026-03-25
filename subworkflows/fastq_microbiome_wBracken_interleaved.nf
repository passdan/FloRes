// Load modules
include { runkrakenInterleaved ; runbracken ; krakenresults ; brackenresults ; dlkraken} from '../modules/Microbiome/kraken_and_bracken.nf' 

workflow FASTQ_KRAKEN_AND_BRACKEN_WF {
    take: 
        fastq_ch
        krakendb
        taxlevel_ch
 
    main:
        if (params.kraken_db == null) {
            if (file("$baseDir/data/kraken_db/minikraken_8GB_20200312/").isDirectory()) {
                kraken_db_ch = Channel.fromPath("$baseDir/data/kraken_db/minikraken_8GB_20200312/")
            } else {
                dlkraken()
                kraken_db_ch = dlkraken.out
            }
        } else {
            kraken_db_ch = Channel.fromPath(params.kraken_db)
        }
	
	// Run Kraken
        runkrakenInterleaved(fastq_ch, krakendb)
        krakenresults(runkrakenInterleaved.out.kraken_report.collect())

        def combined_ch = runkrakenInterleaved.out.bracken_input.combine(taxlevel_ch).set { combined_input_ch }

        runbracken(combined_input_ch, krakendb)

	runbracken.out.bracken_by_level
        	.groupTuple()
	        .set { grouped_bracken_results }

        brackenresults(grouped_bracken_results)
        
}

