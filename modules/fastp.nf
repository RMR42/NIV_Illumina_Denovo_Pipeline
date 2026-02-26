// Fastp trimming
process FASTP {
    tag "${sample_id}"
    publishDir "${params.trimmed_reads}", mode: 'copy'

    input:
    tuple val(sample_id), path(reads)

    output:
    tuple val(sample_id), path("*.fq.gz")
    path "reports/*"

    script:
    """

    mkdir -p reports

    fastp -q 20 -u 30 -n 5 -I 50 --dedup --detect_adapter_for_pe -i ${reads[0]} -I ${reads[1]} -o "${sample_id}_R1.fq.gz" -O "${sample_id}_R2.fq.gz" --json "reports/${sample_id}.json" --html "reports/${sample_id}.html"

    """
}
