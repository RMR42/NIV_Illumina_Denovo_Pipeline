#!/usr/bin/env nextflow
// main.nf

nextflow.enable.dsl=2

// Help message
def helpMessage() {
    log.info """
    ========================================================================
    Viral Short-Read Assembly Pipeline
    ========================================================================

    USAGE:

    Step 1: Collect parameters interactively and run pipeline
    ---------------------------------------------------------
    ./bin/run_pipeline.sh -i

    Step 2 (optional): Run in background
    -------------------------------------
    ./bin/run_pipeline.sh -i -b

    Other options:
    --------------
    # Use an existing parameter file
    ./bin/run_pipeline.sh -f pipeline_params.json

    # Resume a failed or interrupted run
    ./bin/run_pipeline.sh -r

    # Direct nextflow command (advanced)
    nextflow run main.nf \\
        -params-file pipeline_params.json \\
        -profile conda

    PARAMETERS:
    --input_dir   : Directory containing paired-end FASTQ files (required)
    --outdir      : Output directory (default: ./results)
    --do_norm     : Perform read depth normalization via BBNorm (default: true)

    PROFILES:
    conda         : Local execution via conda (recommended for most users)
    hpc           : SLURM cluster with environment modules

    OPTIONS:
    --help        : Display this help message

    ========================================================================
    """.stripIndent()
}

// Show help message if requested
if (params.help) {
    helpMessage()
    exit 0
}

// Validate required parameters
if (!params.input_dir) {
    log.error "ERROR: --input_dir is required!"
    log.info "Run with --help for usage information"
    exit 1
}

// Display parameter summary
log.info """
========================================================================
Pipeline Parameters
========================================================================
Input directory     : ${params.input_dir}
Output directory    : ${params.outdir}
Do normalization    : ${params.do_norm}
Reports directory   : ${params.reports_dir}
========================================================================
"""

log.info "✅ Input dir: ${params.input_dir}"
log.info "✅ Output dir: ${params.outdir}"

include { RAW_FASTQC } from './modules/raw_fastqc.nf'
include { FASTP } from './modules/fastp.nf'
include { FINAL_FASTQC } from './modules/final_fastqc.nf'
include { SPADES_ASSEMBLY } from './modules/spades_assembly.nf'
include { NORMALISATION } from './modules/norm.nf'
include { QUAST } from './modules/quast.nf'

workflow {
    // Read input files
    reads_ch = Channel
        .fromFilePairs("${params.input_dir}/*_L001_{R1,R2}_001.fastq.gz")
        .mix(
            Channel.fromFilePairs("${params.input_dir}/*_{1,2}.fastq")
        )
        .mix(
            Channel.fromFilePairs("${params.input_dir}/*_{R1,R2}.fastq.gz")
        )
        .mix(
            Channel.fromFilePairs("${params.input_dir}/*_L001_{R1,R2}_001.fastq")
        )

    
    // Split channel for parallel processes
    reads_ch
        .multiMap { sample_id, files ->
            fastqc: tuple(sample_id, files)
            fastp: tuple(sample_id, files)
        }
        .set { reads_split }
    
    // Quality control on raw reads
    RAW_FASTQC(reads_split.fastqc)
    
    // Trim reads and collect reports
    (trimmed_reads_ch, fastp_trimmed_reports) = FASTP(reads_split.fastp)
    
    // Quality control on trimmed reads
    FINAL_FASTQC(trimmed_reads_ch)
    
    // Conditional normalization and assembly
    if (params.do_norm) {
        norm_reads_ch = NORMALISATION(trimmed_reads_ch)
        spades_contigs_ch = SPADES_ASSEMBLY(norm_reads_ch)
    } else {
        spades_contigs_ch = SPADES_ASSEMBLY(trimmed_reads_ch)
    }
    
    // Assembly quality assessment
    QUAST(spades_contigs_ch)
}

workflow.onComplete {
    log.info ""
    log.info "========================================================================="
    log.info "Pipeline completed at: $workflow.complete"
    log.info "Execution status: ${ workflow.success ? 'SUCCESS' : 'FAILED' }"
    log.info "Duration: $workflow.duration"
    log.info ""
    log.info "Reports available at:"
    log.info "  - ${params.reports_dir}/execution_report.html"
    log.info "  - ${params.reports_dir}/timeline.html"
    log.info "  - ${params.reports_dir}/trace.txt"
    log.info "========================================================================="
}
