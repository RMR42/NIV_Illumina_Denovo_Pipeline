// BBTools Normalisation
process NORMALISATION {
    tag "${sample_id}"

    publishDir "${params.normalised_reads}", mode: 'copy'

    input:
    tuple val(sample_id), path(reads)

    output:
    tuple val(sample_id), path("normalised_reads/*.fq.gz")

    script:
    """

    mkdir -p normalised_reads

    bbnorm.sh in=${reads[0]} in2=${reads[1]} out=normalised_reads/${sample_id}_out_R1.fq.gz out2=normalised_reads/${sample_id}_out_R2.fq.gz target=40 mindepth=5 threads=8 -Xmx24g

    """
}
