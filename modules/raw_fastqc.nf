// Quality Check with FastQC
process RAW_FASTQC {
    tag "${sample_id}"
    
    publishDir "${params.raw_fastqc_reports}", mode: 'copy'

    input:
    tuple val(sample_id), path(reads)

    output:
    path "*"

    script:
    """

    echo "Processing the ${sample_id}"

    #quality check
    fastqc ${reads} --quiet

    echo "Initial Qaulity check Done for ${sample_id}"

    """

}
