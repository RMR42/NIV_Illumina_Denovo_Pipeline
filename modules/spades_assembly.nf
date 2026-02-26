// Spades Assembly
process SPADES_ASSEMBLY {
    tag "${sample_id}"

    publishDir "${params.assembly_dir}", mode: 'copy'

    input:
    tuple val(sample_id), path(reads)

    output:
    tuple val(sample_id), path("${sample_id}/contigs.fasta")
    

    script:
    """
    
    # Assembly

    echo ${sample_id}

    spades.py --rnaviral -1 ${reads[0]} -2 ${reads[1]} -o ${sample_id}
    
    """
}
