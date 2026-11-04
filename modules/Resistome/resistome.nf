// Resistome quantification, SNP confirmation, rarefaction and normalisation.

include { as_bool } from '../functions.nf'

process build_dependencies {
    tag "Fetching resistome dependencies"
    label "python"

    // nextflow lint warns about projectDir in a process. It is deliberate here:
    // the compiled binaries and the SNP code are cached into the repo so later
    // runs reuse them. RESISTOME_WF checks for them before calling this.
    publishDir "${projectDir}/bin/", mode: "copy"

    output:
    path ("rarefaction"), emit: rarefactionanalyzer
    path ("resistome"), emit: resistomeanalyzer
    path ("AmrPlusPlus_SNP"), emit: amrsnp

    script:
    """
    cp /opt/amrplusplus/bin/rarefaction .
    cp /opt/amrplusplus/bin/resistome .

    git clone https://github.com/Isabella136/AmrPlusPlus_SNP.git
    chmod -R 777 AmrPlusPlus_SNP/
    """
}

process runresistome {
    tag { sample_id }
    label "alignment"

    publishDir "${params.output}/ResistomeAnalysis/ResistomeCounts", mode: "copy", saveAs: { filename -> filename.endsWith(".tsv") ? filename : null }

    input:
    tuple val(sample_id), path(bam)
    path amr
    path annotation
    path resistome
    val prefix

    output:
    tuple val(sample_id), path("${sample_id}*.tsv"), emit: resistome_tsv
    path ("${sample_id}.${prefix}.gene.tsv"), emit: resistome_counts

    script:
    """
    \${SAMTOOLS:-samtools} view -h ${bam} > ${sample_id}.sam

    chmod +x ${resistome}
    ./${resistome} -ref_fp ${amr} \\
        -annot_fp ${annotation} \\
        -sam_fp ${sample_id}.sam \\
        -gene_fp ${sample_id}.${prefix}.gene.tsv \\
        -group_fp ${sample_id}.${prefix}.group.tsv \\
        -mech_fp ${sample_id}.${prefix}.mechanism.tsv \\
        -class_fp ${sample_id}.${prefix}.class.tsv \\
        -type_fp ${sample_id}.${prefix}.type.tsv \\
        -t ${params.threshold}

    rm ${sample_id}.sam
    """
}

process resistomeresults {
    tag "Make AMR count matrix"
    label "python"

    publishDir "${params.output}/Results", mode: "copy"

    input:
    path resistomes
    val prefix

    output:
    path ("${prefix}_analytic_matrix.csv"), emit: raw_count_matrix

    script:
    """
    amr_long_to_wide.py \\
        -i ${resistomes} -o ${prefix}_analytic_matrix.csv
    """
}

process runrarefaction {
    tag { sample_id }
    label "alignment"

    publishDir "${params.output}/ResistomeAnalysis/Rarefaction/Counts", mode: "copy", saveAs: { filename -> filename.endsWith(".tsv") ? filename : null }

    input:
    tuple val(sample_id), path(bam)
    path annotation
    path amr
    path rarefaction

    output:
    path ("*.tsv"), emit: rarefaction

    script:
    """
    \${SAMTOOLS:-samtools} view -h ${bam} > ${sample_id}.sam

    chmod +x ${rarefaction}
    ./${rarefaction} \\
        -ref_fp ${amr} \\
        -sam_fp ${sample_id}.sam \\
        -annot_fp ${annotation} \\
        -gene_fp ${sample_id}.gene.tsv \\
        -group_fp ${sample_id}.group.tsv \\
        -mech_fp ${sample_id}.mech.tsv \\
        -class_fp ${sample_id}.class.tsv \\
        -type_fp ${sample_id}.type.tsv \\
        -min ${params.min} \\
        -max ${params.max} \\
        -skip ${params.skip} \\
        -samples ${params.samples} \\
        -t ${params.threshold}

    rm ${sample_id}.sam
    """
}

process plotrarefaction {
    tag "Plot rarefaction results"
    label "python"

    publishDir "${params.output}/ResistomeAnalysis/Rarefaction/Figures", mode: "copy", saveAs: { filename -> filename.endsWith(".png") ? filename : null }

    input:
    path rarefaction

    output:
    path ("*.png"), emit: plots

    script:
    """
    mkdir -p data/
    mv *.tsv data/
    rfplot.py --dir ./data --nd --s --sd .
    """
}

process runsnp {
    tag { sample_id }
    label "python"

    publishDir "${params.output}/ResistomeAnalysis", mode: "copy", saveAs: { filename ->
        if (filename.endsWith(".csv")) {
            "SNP_verification/${filename}"
        }
        else if (filename.endsWith(".tsv")) {
            "SNP_verification_counts/${filename}"
        }
        else {
            null
        }
    }

    input:
    tuple val(sample_id), path(bam)
    path snp_count_matrix
    path amrsnp
    val prefix

    output:
    path ("${sample_id}.SNP_confirmed_gene.tsv"), emit: snp_counts
    path "${sample_id}.${prefix}_SNPs${sample_id}/*"

    script:
    """
    cp -r ${amrsnp}/* .

    # Keep the bam name consistent with the count matrix name
    if [ "${bam}" != "${sample_id}.bam" ]; then
        mv ${bam} ${sample_id}.bam
    fi

    \${PYTHON3:-python3} SNP_Verification.py -c config.ini -t ${task.cpus} -a true \\
        -i ${sample_id}.bam -o ${sample_id}.${prefix}_SNPs \\
        --count_matrix ${snp_count_matrix}

    cut -d ',' -f `awk -v RS=',' "/${sample_id}/{print NR; exit}" ${sample_id}.${prefix}_SNPs${snp_count_matrix}` \\
        ${sample_id}.${prefix}_SNPs${snp_count_matrix} > ${sample_id}.${prefix}_SNP_count_col

    cut -d ',' -f 1 ${sample_id}.${prefix}_SNPs${snp_count_matrix} > gene_accession_labels

    paste gene_accession_labels ${sample_id}.${prefix}_SNP_count_col > ${sample_id}.SNP_confirmed_gene.tsv
    """
}

process snpresults {
    tag "Make SNP-confirmed matrix"
    label "python"

    publishDir "${params.output}/Results", mode: "copy"

    input:
    path snp_counts
    val prefix

    output:
    path ("SNPconfirmed_${prefix}_analytic_matrix.csv"), emit: snp_matrix

    script:
    """
    snp_long_to_wide.py \\
        -i ${snp_counts} -o SNPconfirmed_${prefix}_analytic_matrix.csv
    """
}

process normalise_matrix {
    tag { "Normalise ${count_matrix.baseName}" }
    label "python"

    publishDir "${params.output}/Results", mode: "copy"

    input:
    path count_matrix
    path kraken_matrix
    path kraken_unclassifieds
    path gene_lengths

    output:
    path ("${count_matrix.baseName}_normalised.csv"), emit: normalised_matrix

    script:
    """
    normalise_to_length.py \\
        -i ${count_matrix} \\
        -k ${kraken_matrix} \\
        -u ${kraken_unclassifieds} \\
        -l ${gene_lengths} \\
        -b ${params.depth_basis} \\
        -o ${count_matrix.baseName}_normalised.csv
    """
}
