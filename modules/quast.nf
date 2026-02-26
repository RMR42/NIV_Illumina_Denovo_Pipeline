process QUAST {
    tag "${sample_id}"
    
    publishDir "${params.post_assembly_dir}", mode: 'copy'

    input:
    tuple val(sample_id), path(contigs)

    output:
    path "quast_results/*"

    script:
    """

    mkdir -p quast_results

    quast.py -o quast_results/${sample_id} --min-identity 80 ${contigs}

    """

    
}
