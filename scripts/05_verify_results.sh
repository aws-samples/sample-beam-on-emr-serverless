#!/bin/bash

# Verify the results of the Beam pipeline

# Load environment variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/config"
source $CONFIG_DIR/env.sh || { echo "Error: Failed to load environment variables"; exit 1; }

echo "Verifying results of the Beam pipeline"

# Navigate to beam-demo directory
cd $BEAM_DEMO_DIR || { echo "Error: Failed to change to beam-demo directory"; exit 1; }

# List output files
echo "Output files in S3:"
aws s3 ls s3://$BUCKET_NAME/results/ --region $AWS_REGION || echo "Warning: Failed to list output files in S3"

# Create output directory
mkdir -p output || echo "Warning: Failed to create output directory"

# Download output files
echo "Downloading output files"
aws s3 cp s3://$BUCKET_NAME/results/ ./output --recursive --region $AWS_REGION || echo "Warning: Failed to download output files"

# Check if output files exist
if [ ! "$(ls -A output 2>/dev/null)" ]; then
    echo "Error: No output files found"
    exit 1
fi

# View sample output
echo "Sample output:"
head -n 20 output/output.txt-* || echo "Warning: Failed to display sample output"

# Get total word count
total_words=$(awk '{split($0,a,": "); sum += a[2]} END {print sum}' output/output.txt-*) || echo "Warning: Failed to calculate total word count"
echo "Total words processed: $total_words"

# Get top 10 most frequent words
echo "Top 10 most frequent words:"
sort -t: -k2 -nr output/output.txt-* | head -n 10 || echo "Warning: Failed to display top 10 words"

echo "Results verification complete"