#!/bin/bash

# Run Apache Beam pipeline on EMR Serverless

# Remove set -e to continue on errors
# Load environment variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/config"
source $CONFIG_DIR/env.sh || { echo "Error: Failed to load environment variables"; exit 1; }

echo "Running Apache Beam pipeline on EMR Serverless"

# Navigate to beam-demo directory
cd $BEAM_DEMO_DIR || { echo "Error: Failed to change to beam-demo directory"; exit 1; }

# Activate virtual environment
source build-environment/bin/activate || echo "Warning: Failed to activate virtual environment"

# Package the pipeline
python3 wordcount.py --output_executable_path=./wordcountApp.jar \
    --runner=SparkRunner \
    --environment_type=PROCESS \
    --environment_config='{"command":"/opt/apache/beam/boot"}' \
    --input=s3://${BUCKET_NAME}/kinglear.txt \
    --output=s3://${BUCKET_NAME}/results/output.txt || { echo "Error: Failed to package pipeline"; exit 1; }

# Upload the packaged pipeline to S3
echo "Uploading packaged pipeline to S3"
aws s3 cp wordcountApp.jar s3://${BUCKET_NAME}/app/ --region $AWS_REGION || echo "Warning: Failed to upload packaged pipeline to S3"

# Create job driver configuration using the specified parameters
ENTRYPOINT='{
"sparkSubmit": {
"entryPoint": "s3://'${BUCKET_NAME}'/app/wordcountApp.jar",
               "sparkSubmitParameters": "--class org.apache.beam.runners.spark.SparkPipelineRunner --conf spark.emr-serverless.driverEnv.PYSPARK_DRIVER_PYTHON=/opt/venv/bin/python3 --conf spark.emr-serverless.driverEnv.PYSPARK_PYTHON=/opt/venv/bin/python3 --conf spark.executorEnv.PYSPARK_PYTHON=/opt/venv/bin/python3"}
}'

# Submit the job
echo "Submitting job to EMR Serverless"
JOB_RUN_ID=$(aws emr-serverless start-job-run --application-id $APPLICATION_ID \
    --execution-role-arn $EMR_ROLE_ARN  --job-driver "${ENTRYPOINT}" \
    --region $AWS_REGION \
    --output text --query jobRunId) || { echo "Error: Failed to submit job"; exit 1; }

echo "Job submitted. Job Run ID: $JOB_RUN_ID"
# Store job run ID in config
echo "export JOB_RUN_ID=$JOB_RUN_ID" >> $CONFIG_DIR/env.sh || echo "Warning: Failed to store job run ID"

# Function to check job status
check_job_status() {
    aws emr-serverless get-job-run \
        --application-id $APPLICATION_ID \
        --job-run-id $JOB_RUN_ID \
        --region $AWS_REGION \
        --query jobRun.state \
        --output text
}

# Monitor job until completion
echo "Monitoring job status..."
while true; do
    STATUS=$(check_job_status) || STATUS="UNKNOWN"
    echo "Current status: $STATUS"
    if [[ "$STATUS" == "SUCCESS" || "$STATUS" == "FAILED" || "$STATUS" == "UNKNOWN" ]]; then
        break
    fi
    sleep 30
done

# Get Spark History Server URL for detailed logs
if [[ "$STATUS" == "SUCCESS" ]]; then
    URL=$(aws emr-serverless get-dashboard-for-job-run \
        --application-id $APPLICATION_ID \
        --job-run-id $JOB_RUN_ID \
        --region $AWS_REGION \
        --output text --query url) || echo "Warning: Failed to get dashboard URL"
    echo "Job completed successfully. Spark History Server URL: $URL"
elif [[ "$STATUS" == "CANCELLED" ]]; then
    echo "Job was cancelled by user or system. Check CloudWatch logs for details."
else
    echo "Job failed or status unknown. Check CloudWatch logs for details."
fi