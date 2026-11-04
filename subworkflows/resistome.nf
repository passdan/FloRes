// Resistome quantification from aligned BAMs.
//
// Used for both the standard and the deduplicated counts: the caller supplies the
// output prefix, which replaces the addParams(prefix: ...) include clause that the
// strict syntax parser no longer accepts.

include { build_dependencies ; runresistome ; resistomeresults ; runrarefaction ; plotrarefaction ; runsnp ; snpresults } from "${projectDir}/modules/Resistome/resistome.nf"
include { as_bool } from "${projectDir}/modules/functions.nf"

workflow RESISTOME_WF {
    take:
        bam_ch
        amr
        annotation
        prefix
        with_rarefaction

    main:
        // Resolve the resistome/rarefaction binaries and the SNP verification code
        if( file("${projectDir}/bin/AmrPlusPlus_SNP/SNP_Verification.py").exists() ) {
            resistomeanalyzer  = file("${projectDir}/bin/resistome")
            rarefactionanalyzer = file("${projectDir}/bin/rarefaction")
        }
        else {
            build_dependencies()
            resistomeanalyzer   = build_dependencies.out.resistomeanalyzer
            rarefactionanalyzer = build_dependencies.out.rarefactionanalyzer
        }

        runresistome(bam_ch, amr, annotation, resistomeanalyzer, prefix)
        resistomeresults(runresistome.out.resistome_counts.collect(), prefix)

        if( as_bool(with_rarefaction) ) {
            runrarefaction(bam_ch, annotation, amr, rarefactionanalyzer)
            plotrarefaction(runrarefaction.out.rarefaction.collect())
        }

        snp_matrix_ch = channel.empty()
        if( as_bool(params.snp) ) {
            runsnp(bam_ch, resistomeresults.out.raw_count_matrix, prefix)
            snpresults(runsnp.out.snp_counts.collect(), prefix)
            snp_matrix_ch = snpresults.out.snp_matrix
        }

    emit:
        raw_count_matrix = resistomeresults.out.raw_count_matrix
        snp_matrix       = snp_matrix_ch
}
