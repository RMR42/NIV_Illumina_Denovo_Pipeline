#!/usr/bin/env python3
"""
Interactive script to collect pipeline parameters and save to JSON

"""
import json
import os
from pathlib import Path

def get_user_input(prompt, default=None, input_type=str):
    """Get user input with optional default value"""
    if default is not None:
        prompt = f"{prompt} [{default}]: "
    else:
        prompt = f"{prompt}: "
    
    while True:
        user_input = input(prompt).strip()
        
        # Use default if no input provided
        if not user_input and default is not None:
            return default
        
        # Validate input
        if not user_input and default is None:
            print("This field is required. Please provide a value.")
            continue
        
        # Type conversion
        if input_type == bool:
            if user_input.lower() in ['true', 'yes', 'y', '1']:
                return True
            elif user_input.lower() in ['false', 'no', 'n', '0']:
                return False
            else:
                print("Please enter true/false or yes/no")
                continue
        
        try:
            return input_type(user_input)
        except ValueError:
            print(f"Invalid input. Expected {input_type.__name__}")
            continue

def validate_directory(path):
    """Validate if directory exists"""
    if path and not os.path.exists(path):
        create = input(f"Directory '{path}' does not exist. Create it? (y/n): ")
        if create.lower() in ['y', 'yes']:
            os.makedirs(path, exist_ok=True)
            return True
        return False
    return True

def collect_parameters():
    """Collect all pipeline parameters from user"""
    print("\n" + "="*60)
    print("Pipeline Parameter Configuration")
    print("="*60 + "\n")
    
    params = {}
    execution_opts = {}
    
    # Essential parameters
    print("--- Essential Parameters ---")
    params['input_dir'] = get_user_input("Input directory path", None, str)
    if not validate_directory(params['input_dir']):
        print("Warning: Input directory does not exist!")
    
    params['outdir'] = get_user_input("Output directory path", "./results", str)
    validate_directory(params['outdir'])
    
    # Processing options
    print("\n--- Processing Options ---")
    params['do_norm'] = get_user_input("Perform normalization? (true/false)", True, bool)
    
    # Execution profile
    print("\n--- Execution Options ---")
    print("Available profiles: conda, hpc")
    profile = get_user_input("Execution profile", "conda", str)
    execution_opts['profile'] = profile
    
    return params, execution_opts

def save_params(params, execution_opts, params_file="pipeline_params.json", exec_file="execution_opts.json"):
    """Save parameters to JSON files"""
    with open(params_file, 'w') as f:
        json.dump(params, f, indent=4)
    print(f"\n✓ Pipeline parameters saved to {params_file}")
    
    with open(exec_file, 'w') as f:
        json.dump(execution_opts, f, indent=4)
    print(f"✓ Execution options saved to {exec_file}")

def display_summary(params, execution_opts):
    """Display summary of collected parameters"""
    print("\n" + "="*60)
    print("Parameter Summary")
    print("="*60)
    print("\n>> Pipeline Parameters:")
    for key, value in params.items():
        print(f"  {key:25s}: {value}")
    print("\n>> Execution Options:")
    for key, value in execution_opts.items():
        print(f"  {key:25s}: {value}")
    print("="*60 + "\n")

def main():
    """Main function"""
    try:
        params, execution_opts = collect_parameters()
        display_summary(params, execution_opts)
        
        # Confirm before saving
        confirm = get_user_input("Save these parameters? (y/n)", "y", str)
        if confirm.lower() in ['y', 'yes']:
            save_params(params, execution_opts)
            print("\nYou can now run your pipeline with:")
            print("  ./bin/run_pipeline.sh")
            print("\nOr manually:")
            print(f"  nextflow run main.nf -params-file pipeline_params.json -profile {execution_opts['profile']}")
        else:
            print("Parameters not saved.")
    
    except KeyboardInterrupt:
        print("\n\nOperation cancelled by user.")
        exit(1)

if __name__ == "__main__":
    main()
