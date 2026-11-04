// FloRes / AMR++ : resistome and microbiome characterisation.
//
// Written for the strict syntax parser, which is the default from Nextflow 26.04.
// See docs/nextflow-26-migration.md for what that required.
//
// Example:
//   nextflow run . -profile conda --reads "data/raw/*_R{1,2}.fastq.gz"
//   nextflow run . -profile conda --reads "..." --host_removal false --bracken false

include { AMRPLUSPLUS } from './subworkflows/amrplusplus.nf'
include { RESISTOME_WF } from './subworkflows/resistome.nf'
include { FASTQ_QC_WF } from './subworkflows/fastq_information.nf'
include { FASTQ_ALIGN_WF } from './subworkflows/fastq_align.nf'
include { FASTQ_MICROBIOME_WF } from './subworkflows/fastq_microbiome.nf'
include { SAMTOOLS_BAM2FQ } from './modules/Tools/bam2fq.nf'
include { as_bool ; check_file } from './modules/functions.nf'

def pipelines() {
    return ['standard', 'bam', 'hifi', 'qc', 'align', 'kraken']
}

def retired() {
    return ['demo': '--pipeline standard --host_removal false', 'fast_AMR': '--pipeline standard --host_removal false', 'standard_AMR': '--pipeline standard --kraken false', 'standard_AMR_wKraken': '--pipeline standard --bracken false', 'standard_AMR_wKraken_and_Bracken': '--pipeline standard', 'standard_hifi': '--pipeline hifi', 'resistome': '--pipeline standard --kraken false --trim false --host_removal false', 'resistome_BWA': '--pipeline standard --kraken false --trim false --host_removal false', 'bam_resistome': '--pipeline bam', 'kraken_and_bracken': '--pipeline kraken', 'eval_qc': '--pipeline qc', 'trim_qc': '--pipeline standard --kraken false', 'rm_host': '--pipeline standard --kraken false', 'qiime2': 'removed: 16S/QIIME2 support has been dropped']
}

def helpMessage() {
    log.info(
        """
    FloRes / AMR++ Nextflow pipeline
    ================================

    Usage:
        nextflow run . -profile <profile> --reads "path/to/*_R{1,2}.fastq.gz"

    Pipelines (--pipeline, default: standard)
        standard   Full pipeline: QC, trimming, host removal, resistome, Kraken,
                   Bracken and length normalisation. Stages are toggled with the
                   parameters below rather than by choosing a different pipeline.
        bam        Resistome quantification from existing BAM alignments (--bam_files).
        hifi       Convert HiFi BAMs to FASTQ (--bam_files), then run the standard pipeline.
        qc         FastQC and MultiQC only.
        align      Bowtie2 alignment to MEGARes only.
        kraken     Kraken2 (and Bracken) classification only.

    Stage toggles (all true/false)
        --fastqc              Run FastQC and MultiQC          (default: true)
        --trim                Run fastp trimming              (default: true)
        --host_removal        Remove host reads with bowtie2  (default: true)
        --snp                 Run SNP confirmation            (default: true)
        --deduped             Also produce deduplicated counts(default: false)
        --kraken              Run Kraken2 classification      (default: true)
        --bracken             Run Bracken after Kraken2       (default: true)
        --normalise_to_length Normalise matrices to gene length and depth (default: true)

    Normalisation
        --depth_basis         classified | total              (default: classified)
                              classified uses the Kraken matrix column sums, i.e.
                              classified reads. total adds unclassified reads from
                              kraken_unclassifieds.csv. Values are not comparable
                              between the two bases.
        --megares_lengths     MEGARes gene lengths table (gene_accession<TAB>bp)

    Profiles (-profile)
        local, local_slurm, conda, conda_slurm, singularity, singularity_slurm,
        apptainer_slurm, docker, google-batch, workbench

    Run --help for this message.
    """
    )
}

workflow {
    if (as_bool(params.help)) {
        helpMessage()
        return null
    }

    def valid = pipelines()
    if (!valid.contains(params.pipeline)) {
        def dead = retired()
        if (dead.containsKey(params.pipeline)) {
            error("--pipeline ${params.pipeline} was removed in this version. Use: ${dead[params.pipeline]}")
        }
        error("Unknown --pipeline '${params.pipeline}'. Choose one of: ${valid.join(', ')}")
    }

    log.info(
        """
    A M R + +   N F   P I P E L I N E
    =================================
    pipeline     : ${params.pipeline}
    reads        : ${params.reads}
    bams         : ${params.bam_files}
    output       : ${params.output}
    """.stripIndent()
    )

    def needs_reads = ['standard', 'qc', 'align', 'kraken'].contains(params.pipeline)
    def needs_bams = ['bam', 'hifi'].contains(params.pipeline)

    if (needs_reads && !params.reads) {
        error("--pipeline ${params.pipeline} needs --reads")
    }
    if (needs_bams && !params.bam_files) {
        error("--pipeline ${params.pipeline} needs --bam_files")
    }

    fastq_ch = channel.empty()
    if (needs_reads) {
        fastq_ch = channel.fromFilePairs(params.reads, size: params.reads.contains('{') ? 2 : 1)
            .ifEmpty { error("Cannot find any reads matching: ${params.reads}") }
            .map { id, files -> tuple(id.split('\\.')[0], files) }
    }

    bam_ch = channel.empty()
    if (needs_bams) {
        bam_ch = channel.fromPath(params.bam_files)
            .ifEmpty { error("Cannot find any bam files matching: ${params.bam_files}") }
            .map { entry -> tuple(entry.baseName.split('\\.')[0], entry) }
    }

    taxlevel_ch = channel.fromList(params.taxlevel.tokenize(','))

    if (params.pipeline == 'standard') {
        AMRPLUSPLUS(
            fastq_ch,
            as_bool(params.host_removal) ? check_file(params.host, 'host') : [],
            check_file(params.amr, 'amr'),
            check_file(params.annotation, 'annotation'),
            params.kraken_db,
            taxlevel_ch,
        )
    }
    else if (params.pipeline == 'hifi') {
        SAMTOOLS_BAM2FQ(bam_ch, params.split)
        AMRPLUSPLUS(
            SAMTOOLS_BAM2FQ.out.reads,
            as_bool(params.host_removal) ? check_file(params.host, 'host') : [],
            check_file(params.amr, 'amr'),
            check_file(params.annotation, 'annotation'),
            params.kraken_db,
            taxlevel_ch,
        )
    }
    else if (params.pipeline == 'bam') {
        RESISTOME_WF(
            bam_ch,
            check_file(params.amr, 'amr'),
            check_file(params.annotation, 'annotation'),
            params.prefix,
            true,
        )
    }
    else if (params.pipeline == 'qc') {
        FASTQ_QC_WF(fastq_ch, params.multiqc)
    }
    else if (params.pipeline == 'align') {
        FASTQ_ALIGN_WF(fastq_ch, check_file(params.amr, 'amr'))
    }
    else if (params.pipeline == 'kraken') {
        FASTQ_MICROBIOME_WF(fastq_ch, params.kraken_db, taxlevel_ch)
    }

    workflow.onComplete = {
        log.info(
            """
        Pipeline completed!
        Started at   : ${workflow.start}
        Finished at  : ${workflow.complete}
        Time elapsed : ${workflow.duration}
        Status       : ${workflow.success ? 'OK' : 'failed'}
        """.stripIndent()
        )
    }
}
