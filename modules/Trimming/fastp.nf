include {adapter_error} from "$baseDir/modules/nf-functions.nf"

if( params.adapters ) {
    adapters = file(params.adapters)
    if( !adapters.exists() ) return adapter_error(adapters)
}

threads = params.threads
//def threads = task.cpus ? task.cpus : params.threads
min = params.min
max = params.max
skip = params.skip
samples = params.samples

leading = params.leading
trailing = params.trailing
slidingwindow = params.slidingwindow
minlen = params.minlen

process runqc {
    tag { sample_id }
    label 'trimming'

    errorStrategy { task.exitStatus in 137..140 ? 'retry' : 'terminate' }
    maxRetries 3

    publishDir "${params.output}/QC_trimming", mode: 'copy', pattern: '*.fastq.gz',
        saveAs: { filename ->
            if(filename.indexOf("P.fastq.gz") > 0) "Paired/$filename"
            else if(filename.indexOf("U.fastq.gz") > 0) "Unpaired/$filename"
            else {}
        }

    input:
        tuple val(sample_id), path(reads)  

    output:
        tuple val(sample_id), path("${sample_id}*P.fastq.gz"), emit: paired_fastq
        path("${sample_id}.fastp.log"), emit: fastp_stats

    """
        ${FASTP} \
            --in1 ${reads[0]} \
            --in2 ${reads[1]} \
            --out1 ${sample_id}.1P.fastq.gz \
            --out2 ${sample_id}.2P.fastq.gz \
            --json ${sample_id}.fastp.json \
            --html ${sample_id}.fastp.html \
            --thread ${task.cpus} \
            --detect_adapter_for_pe \
  	    --trim_poly_g \
            --cut_right \
            2> ${sample_id}.fastp.log
    """

}
