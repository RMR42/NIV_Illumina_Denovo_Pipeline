# Viral Short-Read Assembly Pipeline

A [Nextflow](https://www.nextflow.io/) DSL2 pipeline for *de novo* assembly of viral genomes from Illumina paired-end short reads. The pipeline performs quality control, adapter trimming, optional read depth normalization, genome assembly, and assembly quality assessment.

Developed at **ICMR – National Institute of Virology, Pune**, under the High Performance Computing facility **NAKSHATRA** (PM-ABHIM Grant No. VIR/35/2022/ECD-1).

---

## Table of Contents

- [Overview](#overview)
- [Pipeline Workflow](#pipeline-workflow)
- [Requirements](#requirements)
- [Installation](#installation)
- [Input Files](#input-files)
- [Usage](#usage)
- [Parameters](#parameters)
- [Configuration Profiles](#configuration-profiles)
- [Output Structure](#output-structure)
- [Tool Details](#tool-details)
- [Citation](#citation)
- [Support](#support)

---

## Overview

This pipeline accepts raw paired-end Illumina FASTQ files and produces assembled viral contigs along with comprehensive QC reports at every stage. It is designed to handle multiple samples in parallel and supports multiple execution environments — from a personal laptop (via Conda) to an institutional HPC cluster (via SLURM modules).

---

## Pipeline Workflow

```
Raw FASTQ reads (paired-end)
        │
        ├──────────────────────────┐
        ▼                          ▼
  RAW_FASTQC                    FASTP
  (QC report on                 (Adapter trimming,
   raw reads)                    quality filtering,
                                  deduplication)
                                   │
                          ┌────────┴────────┐
                          ▼                  ▼
                    FINAL_FASTQC        trimmed reads
                    (QC report on            │
                     trimmed reads)          │
                                    ┌────────┴────────┐
                                    │                  │
                             [do_norm=true]     [do_norm=false]
                                    │                  │
                                    ▼                  │
                             NORMALISATION             │
                             (BBNorm read              │
                              depth norm.)             │
                                    │                  │
                                    └────────┬─────────┘
                                             │
                                             ▼
                                     SPADES_ASSEMBLY
                                     (de novo assembly,
                                      --rnaviral mode)
                                             │
                                             ▼
                                          QUAST
                                     (Assembly quality
                                      assessment)
```

---

## Requirements

| Requirement | Version | Notes |
|---|---|---|
| [Conda / Miniconda](https://docs.conda.io/en/latest/miniconda.html) | Any recent | Required to set up environments |
| [Nextflow](https://www.nextflow.io/) | ≥ 23.04 | Installed via conda (see below) |
| Java | ≥ 11 | Installed automatically with the nextflow conda environment |
| Python | ≥ 3.10 | Installed automatically with the nextflow conda environment |
| Operating System | Linux / macOS | Windows users should use WSL2 |

> **HPC users:** Java and Nextflow may already be available as modules on your system. Check with `module avail nextflow` before proceeding.

---

## Installation

### Step 1 — Clone the repository

```bash
git clone https://github.com/RMR42/NIV_Illumina_Denovo_Pipeline.git
cd NIV_Illumina_Denovo_Pipeline
```

### Step 2 — Create the Nextflow launcher environment (one time only)

This creates a minimal conda environment containing Nextflow and its dependencies:

```bash
conda env create -f envs/nextflow.yml
```
> On the first run, Nextflow will automatically build a second conda environment
> containing all pipeline tools. This takes 5–10 minutes and is cached for all
> future runs.

---

## Input Files

The pipeline expects **paired-end Illumina FASTQ files** in a single input directory. The following filename patterns are supported automatically:

| Pattern | Example |
|---|---|
| `*_L001_{R1,R2}_001.fastq.gz` | `sample1_L001_R1_001.fastq.gz` |
| `*_L001_{R1,R2}_001.fastq` | `sample1_L001_R1_001.fastq` |
| `*_{R1,R2}.fastq.gz` | `sample1_R1.fastq.gz` |
| `*_{1,2}.fastq` | `sample1_1.fastq` |

All samples present in the input directory are processed in parallel.

> **Important:** Both files of a pair must share the same sample name prefix and differ only in the read direction identifier (R1/R2 or 1/2).

---

## Usage

The recommended way to run this pipeline is using the `-i` flag on the wrapper script. This launches interactive parameter collection and then starts the pipeline automatically — one command does everything.

---

### Standard run (recommended)

```bash
conda activate nextflow-launcher
./bin/run_pipeline.sh -i
```
You will be prompted for your input directory, output directory, whether to
normalize reads, and execution profile. Once confirmed, parameters are saved
to `pipeline_params.json` and the pipeline starts automatically. Execution
reports, timeline, and resource trace are saved to `<outdir>/reports/`.

### Run in background

```bash
./bin/run_pipeline.sh -i -b
```

Monitor progress with:
```bash
tail -f run_output.txt
```

---

### Resume a failed or interrupted run

Nextflow caches every completed process. If a run fails partway through, resume from the last successful step without reprocessing completed samples:

```bash
./bin/run_pipeline.sh -r
```

---

### Reuse parameters from a previous run

If parameters are already saved from a previous session, skip interactive collection and run directly:

```bash
./bin/run_pipeline.sh -f pipeline_params.json
```

---

### All wrapper script options

```
Usage: run_pipeline.sh [OPTIONS]

  -i, --interactive    Collect parameters interactively, then run pipeline
  -f, --file FILE      Use an existing parameter file (default: pipeline_params.json)
  -b, --background     Run pipeline in background
  -l, --log FILE       Log file for background mode (default: run_output.txt)
  -r, --resume         Resume a previous run
  -h, --help           Show help message
```

---

## Parameters

Full parameter details are documented in `nextflow.config`. The three inputs you will be prompted for are:

| Parameter | Default | Required |
|---|---|---|
| `--input_dir` | `null` | ✅ Yes |
| `--outdir` | `./results` | No |
| `--do_norm` | `true` | No |

All output subdirectory paths are derived automatically from `--outdir`.

---

## Configuration Profiles

| Profile | Use case |
|---|---|
| `conda` | Local machine or any system with conda ✅ recommended |
| `hpc` | SLURM cluster with environment modules (NAKSHATRA) |
---

## Output Structure

After a successful run, the output directory will contain:

```
results/
├── reports/
│   ├── raw_fastqc/               # FastQC reports on raw reads
│   │   ├── <sample>_R1_fastqc.html
│   │   └── <sample>_R1_fastqc.zip
│   ├── trimmed_fastqc/           # FastQC reports on trimmed reads
│   │   ├── <sample>_R1_fastqc.html
│   │   └── <sample>_R1_fastqc.zip
│   ├── execution_report.html     # Nextflow execution report
│   ├── timeline.html             # Process timeline
│   └── trace.txt                 # Resource usage trace
├── trimmed_reads/                # Adapter-trimmed reads (fastp output)
│   ├── <sample>_R1.fq.gz
│   ├── <sample>_R2.fq.gz
│   └── reports/
│       ├── <sample>.html         # fastp per-sample HTML report
│       └── <sample>.json         # fastp per-sample JSON report
├── normalised_reads/             # Depth-normalised reads (if do_norm=true)
│   ├── <sample>_out_R1.fq.gz
│   └── <sample>_out_R2.fq.gz
├── assembly_results/             # SPAdes assembly output
│   └── <sample>/
│       └── contigs.fasta
└── post_assembly_results/        # QUAST quality assessment
    └── quast_results/
        └── <sample>/
            ├── report.html
            ├── report.tsv
            └── report.txt
```

---

## Tool Details

### FastQC (v0.12.1)
Generates per-sample quality reports for raw reads and again after trimming. Reports include per-base quality scores, GC content, adapter content, and sequence duplication levels.

### fastp (v1.0.1)
Trims adapters and low-quality bases from paired-end reads. Parameters used:
- Minimum quality score: `-q 20`
- Maximum percentage of N bases: `-n 5`
- Minimum read length after trimming: `-I 50` (minimum insert size 50)
- Per-read unqualified base limit: `-u 30`
- Deduplication: `--dedup`
- Automatic adapter detection: `--detect_adapter_for_pe`

### BBNorm / BBTools (v39.06)
Normalizes read depth to reduce uneven coverage, which improves assembly quality for viral genomes with variable sequencing depth. Parameters used:
- Target depth: `target=40`
- Minimum depth threshold: `mindepth=5`
- Threads: `threads=8`
- Memory: `-Xmx24g`

> Normalization is optional and can be skipped with `--do_norm false`. This is useful if your data already has uniform coverage or if you are working with low-input samples where read loss is undesirable.

### SPAdes (v4.2.0)
Performs *de novo* genome assembly using the `--rnaviral` mode, which is optimized for RNA virus genomes sequenced via metatranscriptomic or amplicon approaches.

### QUAST (v5.3.0)
Evaluates assembly quality without a reference genome. Metrics reported include: number of contigs, total assembly length, N50, N75, L50, largest contig, and GC content. Minimum contig identity threshold: `--min-identity 80`.

---

## Repository Structure

```
viral-assembly-pipeline/
├── main.nf                   # Main workflow
├── nextflow.config           # Configuration and profiles
├── input_collector.py        # Interactive parameter collection utility
├── run_pipeline.sh           # Wrapper script (optional, for HPC use)
├── envs/
│   ├── nextflow.yml          # Conda environment for running Nextflow
│   └── pipeline.yml          # Conda environment for pipeline tools
├── modules/
│   ├── raw_fastqc.nf         # Raw read QC
│   ├── fastp.nf              # Adapter trimming
│   ├── final_fastqc.nf       # Post-trim QC
│   ├── norm.nf               # Read depth normalization
│   ├── spades_assembly.nf    # De novo assembly
│   └── quast.nf              # Assembly QC
├── trial/                    # Small synthetic FASTQ files for testing
├── LICENSE                   # MIT License
└── README.md                 # This file
```

---

## Citation

If you use this pipeline in your research, please cite:

> Raju, R.M.,Singh, SR.,Ashraf, A.F.,Madiwal, K.,Sarah S Cherian. De novo assembly pipeline for short read viral genomes. Zenodo. https://doi.org/10.5281/zenodo.XXXXXXX

Please also cite the individual tools used:

- **FastQC**: Andrews, S. (2010). FastQC: A quality control tool for high throughput sequence data. https://www.bioinformatics.babraham.ac.uk/projects/fastqc/
- **fastp**: Chen, S. *et al.* (2018). fastp: an ultra-fast all-in-one FASTQ preprocessor. *Bioinformatics*, 34(17), i884–i890. https://doi.org/10.1093/bioinformatics/bty560
- **BBTools**: Bushnell, B. (2014). BBTools software package. https://sourceforge.net/projects/bbmap/
- **SPAdes**: Prjibelski, A. *et al.* (2020). Using SPAdes *de novo* assembler. *Current Protocols in Bioinformatics*, 70(1), e102. https://doi.org/10.1002/cpbi.102
- **QUAST**: Gurevich, A. *et al.* (2013). QUAST: quality assessment tool for genome assemblies. *Bioinformatics*, 29(8), 1072–1075. https://doi.org/10.1093/bioinformatics/btt086
- **Nextflow**: Di Tommaso, P. *et al.* (2017). Nextflow enables reproducible computational workflows. *Nature Biotechnology*, 35, 316–319. https://doi.org/10.1038/nbt.3820

### Acknowledgement for HPC users

This work used the High Performance Computing facility **NAKSHATRA** developed under the Indian Council of Medical Research PM-Ayushman Bharat Health Infrastructure Mission (PM-ABHIM) project (Grant No. VIR/35/2022/ECD-1).

---

## Support
- **Contact:** nakshatrahpc@gmail.com | rmariyamr42@gmail.com

---

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
