// Bowtie2 indexing, alignment and host removal.

process bowtie2_index {
    tag "Creating bowtie2 index"
    label "alignmentBowtie2"

    errorStrategy { task.exitStatus in 137..140 ? 'retry' : 'terminate' }
    maxRetries 3

    publishDir "${params.output}/Alignment/Bowtie2_Index", mode: "copy"

    input:
        path fasta

    output:
        path("${fasta.simpleName}*"), emit: bowtie2index, includeInputs: true

    script:
    """
    bowtie2-build --threads ${task.cpus} ${fasta} ${fasta.simpleName}
    """
}

process bowtie2_align {
    tag "$pair_id"
    label "alignmentBowtie2"

    errorStrategy { task.exitStatus in 137..140 ? 'retry' : 'terminate' }
    maxRetries 3

    publishDir "${params.output}/Alignment/BAM_files/Standard", mode: "copy"

    input:
        path indexfiles
        tuple val(pair_id), path(reads)

    output:
        tuple val(pair_id), path("${pair_id}_alignment_sorted.bam"), emit: bowtie2_bam

    script:
    """
    \${BOWTIE2:-bowtie2} -x ${indexfiles[0].simpleName} -1 ${reads[0]} -2 ${reads[1]} \\
        --threads ${task.cpus} --rg-id ${pair_id} --rg SM:${pair_id} | \\
        \${SAMTOOLS:-samtools} sort -@ ${task.cpus} -m 4G -o ${pair_id}_alignment_sorted.bam
    """
}

process bowtie2_rm_contaminant_fq {
    tag { pair_id }
    label "alignmentBowtie2"

    errorStrategy { task.exitStatus in 137..140 ? 'retry' : 'terminate' }
    maxRetries 3

    publishDir "${params.output}/HostRemoval/NonHostFastq", mode: "copy",
        saveAs: { filename -> filename.endsWith("fastq.gz") ? filename : null }

    input:
        path indexfiles
        tuple val(pair_id), path(reads)

    output:
        tuple val(pair_id), path("${pair_id}.non.host.R*.fastq.gz"), emit: nonhost_reads
        path("${pair_id}.samtools.idxstats"), emit: host_rm_stats

    script:
    """
    \${BOWTIE2:-bowtie2} -x ${indexfiles[0].simpleName} -1 ${reads[0]} -2 ${reads[1]} \\
        --threads ${task.cpus} | \\
        \${SAMTOOLS:-samtools} sort -@ ${task.cpus} -m 6G -o ${pair_id}.host.sorted.bam

    \${SAMTOOLS:-samtools} index ${pair_id}.host.sorted.bam
    \${SAMTOOLS:-samtools} idxstats ${pair_id}.host.sorted.bam > ${pair_id}.samtools.idxstats

    \${SAMTOOLS:-samtools} view -h -f 12 -b ${pair_id}.host.sorted.bam -o ${pair_id}.host.sorted.removed.bam
    rm ${pair_id}.host.sorted.bam ${pair_id}.host.sorted.bam.bai

    \${SAMTOOLS:-samtools} sort -n -@ ${task.cpus} -m 6G ${pair_id}.host.sorted.removed.bam \\
        -o ${pair_id}.host.resorted.removed.bam
    rm ${pair_id}.host.sorted.removed.bam

    \${SAMTOOLS:-samtools} fastq -@ ${task.cpus} -c 6 \\
        ${pair_id}.host.resorted.removed.bam \\
        -1 ${pair_id}.non.host.R1.fastq.gz \\
        -2 ${pair_id}.non.host.R2.fastq.gz \\
        -0 /dev/null -s /dev/null -n

    rm ${pair_id}.host.resorted.removed.bam
    """
}

process HostRemovalStats {
    tag "HostRemovalStats"
    label "python"

    errorStrategy { task.exitStatus in 137..140 ? 'retry' : 'terminate' }
    maxRetries 3

    publishDir "${params.output}/Results/Stats", mode: "copy"

    input:
        path(host_rm_stats)

    output:
        path("host.removal.stats"), emit: combo_host_rm_stats

    script:
    """
    \${PYTHON3:-python3} ${projectDir}/bin/samtools_idxstats.py -i ${host_rm_stats} -o host.removal.stats
    """
}
