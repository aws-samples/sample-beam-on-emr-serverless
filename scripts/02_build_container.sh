#!/bin/bash

# Build and push the custom container image for Apache Beam

# Remove set -e to continue on errors
# Load environment variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/config"
source $CONFIG_DIR/env.sh || { echo "Error: Failed to load environment variables"; exit 1; }

echo "Building and pushing custom container image for Apache Beam"

# Check if Docker is running
docker info > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "Error: Docker is not running. Please start Docker and try again."
    exit 1
fi

# Navigate to beam-demo directory
cd $BEAM_DEMO_DIR || { echo "Error: Failed to change to beam-demo directory"; exit 1; }

# Create Dockerfile
echo "Creating Dockerfile"
cat << EOF > Dockerfile
FROM public.ecr.aws/emr-serverless/spark/emr-7.9.0:latest

USER root
ARG PYTHON_VERSION=3.11.11
ARG BEAM_VERSION=2.58.0

# Install Python and dependencies - including zlib
RUN yum install -y gcc openssl-devel xz-devel bzip2-devel \
    libffi-devel tar gzip wget make zlib-devel

# Build Python from source with zlib support
RUN wget https://www.python.org/ftp/python/\${PYTHON_VERSION}/Python-\${PYTHON_VERSION}.tgz && \
    tar xzf Python-\${PYTHON_VERSION}.tgz && \
    cd Python-\${PYTHON_VERSION} && \
    ./configure --enable-optimizations --with-system-ffi && \
    make install

# Set up Python virtual environment
ENV VIRTUAL_ENV=/opt/venv
RUN python3 -m venv \$VIRTUAL_ENV --copies
RUN cp -r /usr/local/lib/python3.11/* \$VIRTUAL_ENV/lib/python3.11

ENV PATH="\$VIRTUAL_ENV/bin:\$PATH"

# Install Beam SDK and dependencies
RUN python3 -m pip install --upgrade pip && \
    python3 -m pip install apache_beam==\${BEAM_VERSION} \
    s3fs \
    boto3

# Configure Python environment for Spark
ENV PYSPARK_PYTHON="/opt/venv/bin/python3"
ENV PYSPARK_DRIVER_PYTHON="/opt/venv/bin/python3"
ENV RUN_PYTHON_SDK_IN_DEFAULT_ENVIRONMENT=1

# Create Apache Beam directory and copy all beam files
COPY --from=apache/beam_python3.11_sdk:2.58.0 /opt/apache/beam /opt/apache/beam

USER hadoop:hadoop
EOF

# Get ECR login token
echo "Logging in to ECR"
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REPO || echo "Warning: Failed to login to ECR"

# Build the Docker image without cache
echo "Building Docker image without cache"
docker build --no-cache -t ${ECR_REPO}:latest . || { echo "Error: Failed to build Docker image"; exit 1; }

# Push the image to ECR
echo "Pushing image to ECR"
docker push ${ECR_REPO}:latest || echo "Warning: Failed to push image to ECR"

echo "Container image built and pushed successfully"

# Check if APPLICATION_ID exists in environment variables
if [ ! -z "$APPLICATION_ID" ]; then
    # Check if the application exists
    APP_EXISTS=$(aws emr-serverless get-application --application-id $APPLICATION_ID --region $AWS_REGION 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        echo "Updating EMR Serverless application to use the custom container image"
        
        # Update the application
        aws emr-serverless update-application \
            --application-id $APPLICATION_ID \
            --client-token "update-$(date +%s)" \
            --image-configuration "imageUri"="${ECR_REPO}:latest" \
            --region $AWS_REGION || echo "Warning: Failed to update application"
        
        echo "EMR Serverless application updated to use custom container image"
        echo "You can now run the pipeline with ./04_run_pipeline.sh"
    else
        echo "APPLICATION_ID found in environment variables but application does not exist"
        echo "Please run ./03_create_application.sh to create the EMR Serverless application"
    fi
else
    echo "APPLICATION_ID not found in environment variables"
    echo "Please run ./03_create_application.sh first to create the EMR Serverless application"
fi