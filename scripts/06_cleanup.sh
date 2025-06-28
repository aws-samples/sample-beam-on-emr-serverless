#!/bin/bash

# Clean up resources

# Remove set -e to continue on errors
# Load environment variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/config"
source $CONFIG_DIR/env.sh || echo "Warning: Failed to load environment variables"

echo "Cleaning up resources"

# Stop and delete EMR Serverless application
echo "Stopping EMR Serverless application"
aws emr-serverless stop-application --application-id $APPLICATION_ID --region $AWS_REGION || echo "Warning: Failed to stop EMR Serverless application"

# Wait for application to stop
echo "Waiting for application to stop..."
while true; do
    STATUS=$(aws emr-serverless get-application --application-id $APPLICATION_ID --region $AWS_REGION --query application.state --output text 2>/dev/null)
    if [[ "$STATUS" == "STOPPED" || "$STATUS" == "CREATED" || "$?" != "0" ]]; then
        break
    fi
    echo "Current status: $STATUS. Waiting..."
    sleep 10
done

echo "Deleting EMR Serverless application"
aws emr-serverless delete-application --application-id $APPLICATION_ID --region $AWS_REGION || echo "Warning: Failed to delete EMR Serverless application"

# Delete ECR repository
echo "Deleting ECR repository"
aws ecr delete-repository --repository-name beam-blog-repo --force --region $AWS_REGION || echo "Warning: Failed to delete ECR repository"

# Empty and delete S3 bucket
echo "Emptying and deleting S3 bucket"
aws s3 rm s3://$BUCKET_NAME --recursive --region $AWS_REGION || echo "Warning: Failed to empty S3 bucket"
aws s3 rb s3://$BUCKET_NAME --force --region $AWS_REGION || echo "Warning: Failed to delete S3 bucket"

# Delete IAM role and policies
echo "Deleting IAM role and policies"

# List and delete all policies attached to the role
echo "Listing attached policies"
ATTACHED_POLICIES=($(aws iam list-role-policies --role-name beam-blog-emrserverless-role --query 'PolicyNames' --output text)) || echo "Warning: Failed to list policies"

# Delete each policy
for POLICY in ${ATTACHED_POLICIES[@]}; do
    echo "Deleting policy: $POLICY"
    aws iam delete-role-policy --role-name beam-blog-emrserverless-role --policy-name "$POLICY" || echo "Warning: Failed to delete policy $POLICY"
done

# Now delete the role
echo "Deleting IAM role"
aws iam delete-role --role-name beam-blog-emrserverless-role || echo "Warning: Failed to delete IAM role"

echo "Deleting Log Group"
aws logs delete-log-group --log-group-name "/aws/emr-serverless/beam-blog-app" --region $AWS_REGION || echo "Warning: Failed to delete Log Group"

# Clean up local files but preserve the scripts directory
echo "Cleaning up local files"
rm -rf $BEAM_DEMO_DIR || echo "Warning: Failed to remove beam-demo directory"

echo "Cleanup completed"