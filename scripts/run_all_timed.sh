#!/bin/bash

# Run all scripts in sequence and time each one

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/execution_times.log"

echo "Starting timed execution of all scripts at $(date)" | tee $LOG_FILE
echo "----------------------------------------" | tee -a $LOG_FILE

# Function to run a script and time it
run_timed() {
    script=$1
    echo "Running $script..." | tee -a $LOG_FILE
    start_time=$(date +%s)
    $SCRIPT_DIR/$script
    exit_code=$?
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    echo "$script completed in $duration seconds ($(date -u -r $duration +%H:%M:%S))" | tee -a $LOG_FILE
    echo "Exit code: $exit_code" | tee -a $LOG_FILE
    echo "----------------------------------------" | tee -a $LOG_FILE
    
    return $exit_code
}

# Run each script in sequence
run_timed "01_setup_env.sh" && \
run_timed "02_build_container.sh" && \
run_timed "03_create_application.sh" && \
run_timed "04_run_pipeline.sh" && \
run_timed "05_verify_results.sh" && \
run_timed "06_cleanup.sh"

# Print summary
echo "All scripts completed at $(date)" | tee -a $LOG_FILE
echo "See $LOG_FILE for detailed timing information" | tee -a $LOG_FILE