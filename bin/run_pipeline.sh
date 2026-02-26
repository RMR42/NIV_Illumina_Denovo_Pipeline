#!/bin/bash
# run_pipeline.sh - Wrapper script for pipeline execution

set -e  # Exit on error

SCRIPT_DIR="$( dirname "${BASH_SOURCE[0]}" )"
LAUNCH_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
PARAMS_FILE="pipeline_params.json"
EXEC_OPTS_FILE="execution_opts.json"
INTERACTIVE=false
RESUME=false
PROFILE=""
BACKGROUND=false
LOGFILE="run_output.txt"

# Usage function
usage() {
    SCRIPT_NAME=$(basename "$0")

    cat << EOF

================================================================================
Viral Assembly Pipeline for Short Reads (Illumina)
Version 1.0
Maintainer: ICMR - National Institute of Virology, Pune
================================================================================

DESCRIPTION
    De novo assembly pipeline for short read (Illumina) viral genomes.


Usage: ${SCRIPT_NAME} [OPTIONS]

OPTIONS:
  -i, --interactive        Run interactive parameter collection
                           (pipeline starts automatically after this step)
  -f, --file FILE          Parameter file (default: pipeline_params.json)
  -b, --background         Run pipeline in background
  -l, --log FILE           Background log file (default: run_output.txt)
  -h, --help               Show this help message and exit

IMPORTANT:
  • The -i / --interactive option WILL start the pipeline
    automatically after parameter collection.
  • No separate run command is required.
  • Use -b / --background to run the pipeline in background.
    Without -b, the pipeline runs in the terminal (foreground).

WORKFLOW:
  Step 1: Collect parameters and run pipeline
      ${SCRIPT_NAME} -i

  Step 2 (optional): Run in background
      ${SCRIPT_NAME} -i -b

EXAMPLES:
  # Collect parameters and run pipeline (foreground)
  ${SCRIPT_NAME} -i

  # Collect parameters and run pipeline in background
  ${SCRIPT_NAME} -i -b

  # Run using an existing parameter file
  ${SCRIPT_NAME} -f pipeline_params.json

  # Run in background with custom log file
  ${SCRIPT_NAME} -f pipeline_params.json -b -l my_pipeline.log

================================================================================
NOTES
================================================================================

SUPPORT
    For documentation and support, see README.md

EOF
    exit 0
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -i|--interactive)
            INTERACTIVE=true
            shift
            ;;
        -f|--file)
            PARAMS_FILE="$2"
            shift 2
            ;;
        -p|--profile)
            PROFILE="$2"
            shift 2
            ;;
        -r|--resume)
            RESUME=true
            shift
            ;;
        -b|--background)
            BACKGROUND=true
            shift
            ;;
        -l|--log)
            LOGFILE="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            usage
            ;;
    esac
done

# Function to check if file exists
check_file() {
    if [ ! -f "$1" ]; then
        echo -e "${RED}Error: File '$1' not found!${NC}"
        exit 1
    fi
}

# Main execution
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Pipeline Execution Script${NC}"
echo -e "${GREEN}========================================${NC}\n"

# Interactive mode: collect parameters
if [ "$INTERACTIVE" = true ]; then
    echo -e "${YELLOW}Running interactive parameter collection...${NC}\n"
    
    if [ ! -f "${LAUNCH_DIR}/bin/input_collector.py" ]; then
        echo -e "${RED}Error: input_collector.py not found!${NC}"
        exit 1
    fi
    
    python3 ${LAUNCH_DIR}/bin/input_collector.py
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Parameter collection failed!${NC}"
        exit 1
    fi
    
    PARAMS_FILE="pipeline_params.json"
fi

# Check if parameter file exists
check_file "$PARAMS_FILE"

echo -e "${YELLOW}Using parameter file: ${PARAMS_FILE}${NC}\n"

# Extract outdir from params file for report paths
if command -v python3 &> /dev/null; then
    OUTDIR=$(python3 -c "import json; print(json.load(open('$PARAMS_FILE'))['outdir'])" 2>/dev/null || echo "./results")
else
    OUTDIR="./results"
fi

# Ensure reports directory exists
mkdir -p "${OUTDIR}/reports"
echo -e "${YELLOW}Reports will be saved to: ${OUTDIR}/reports${NC}\n"

# Read profile from execution options file if not specified on command line
if [ -z "$PROFILE" ] && [ -f "$EXEC_OPTS_FILE" ]; then
    # Try to extract profile from JSON using python
    if command -v python3 &> /dev/null; then
        PROFILE=$(python3 -c "import json; print(json.load(open('$EXEC_OPTS_FILE')).get('profile', 'conda'))" 2>/dev/null || echo "conda")
    else
        PROFILE="conda"
    fi
    echo -e "${YELLOW}Profile from execution_opts.json: ${PROFILE}${NC}"
elif [ -z "$PROFILE" ]; then
    PROFILE="conda"
    echo -e "${YELLOW}Using default profile: ${PROFILE}${NC}"
else
    echo -e "${YELLOW}Profile from command line: ${PROFILE}${NC}"
fi
echo ""

# Build nextflow command with report flags
NF_CMD="nextflow run ${LAUNCH_DIR}/main.nf \
    -params-file ${PARAMS_FILE} \
    -profile ${PROFILE} \
    -with-report ${OUTDIR}/reports/execution_report.html \
    -with-timeline ${OUTDIR}/reports/timeline.html \
    -with-trace ${OUTDIR}/reports/trace.txt"

if [ "$RESUME" = true ]; then
    NF_CMD="${NF_CMD} -resume"
    echo -e "${YELLOW}Resuming previous pipeline execution...${NC}\n"
fi

# Display the command
echo -e "${GREEN}Executing command:${NC}"
echo -e "${YELLOW}${NF_CMD}${NC}\n"

# Execute pipeline
if [ "$BACKGROUND" = true ]; then
    echo -e "${YELLOW}Running pipeline in background mode...${NC}"
    echo -e "${YELLOW}Log file: ${LOGFILE}${NC}\n"
    
    # Run in background, redirect output to log file, and disown
    eval "$NF_CMD" &> "$LOGFILE" &
    PIPELINE_PID=$!
    
    sleep 0.5
    disown
    
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Pipeline started in background!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo -e "Process ID: ${PIPELINE_PID}"
    echo -e "Log file: ${LOGFILE}"
    echo -e ""
    echo -e "To monitor progress:"
    echo -e "  tail -f ${LOGFILE}"
    echo -e ""
#    echo -e "To check if running:"
#    echo -e "  ps aux | grep nextflow"
#    echo -e ""
    # echo -e "To kill the pipeline:"
    # echo -e "  kill ${PIPELINE_PID}"
    
else
    # Run in foreground (normal mode)
    eval $NF_CMD
    
    # Check execution status
    if [ $? -eq 0 ]; then
        echo -e "\n${GREEN}========================================${NC}"
        echo -e "${GREEN}Pipeline completed successfully!${NC}"
        echo -e "${GREEN}========================================${NC}"
    else
        echo -e "\n${RED}========================================${NC}"
        echo -e "${RED}Pipeline execution failed!${NC}"
        echo -e "${RED}========================================${NC}"
        exit 1
    fi
fi
