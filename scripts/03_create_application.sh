#!/bin/bash

# Create EMR Serverless application

# Remove set -e to continue on errors
# Load environment variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/config"
source $CONFIG_DIR/env.sh || { echo "Error: Failed to load environment variables"; exit 1; }

echo "Creating EMR Serverless application"

# Create application configuration
cat << EOF > application.json
{
    "name": "beam-blog-app",
    "releaseLabel": "emr-7.9.0",
    "type": "SPARK",
    "architecture": "${ARCHITECTURE}",
    "autoStartConfiguration": {
        "enabled": true
    },
    "autoStopConfiguration": {
        "enabled": true,
        "idleTimeoutMinutes": 60
    },
    "initialCapacity": {
        "DRIVER": {
            "workerCount": 1,
            "workerConfiguration": {
                "cpu": "2vCPU",
                "memory": "4GB"
            }
        },
        "EXECUTOR": {
            "workerCount": 2,
            "workerConfiguration": {
                "cpu": "2vCPU",
                "memory": "4GB"
            }
        } 
    },
    "imageConfiguration": {
        "imageUri": "${ECR_REPO}:latest"
    },
    "monitoringConfiguration": {
        "cloudWatchLoggingConfiguration": {
            "enabled": true,
            "logGroupName": "/aws/emr-serverless/beam-blog-app",
            "logStreamNamePrefix": "spark-application-logs"
        }
    }
}
EOF

# Create the application and store the ID
APPLICATION_ID=$(aws emr-serverless create-application \
    --cli-input-json file://application.json \
    --region $AWS_REGION \
    --output text --query applicationId) || { echo "Error: Failed to create EMR Serverless application"; exit 1; }

# Store application ID for later use
echo "export APPLICATION_ID=$APPLICATION_ID" >> $CONFIG_DIR/env.sh || echo "Warning: Failed to store application ID"

echo "EMR Serverless application created with ID: $APPLICATION_ID"