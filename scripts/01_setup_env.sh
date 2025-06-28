#!/bin/bash

# Setup environment for Apache Beam on EMR Serverless

# Remove set -e to continue on errors
echo "Setting up environment for Apache Beam on EMR Serverless"

# Detect architecture
ARCHITECTURE=$(uname -m | awk '{print toupper($0)}') || ARCHITECTURE="X86_64"
if [[ "$ARCHITECTURE" == "AARCH"* ]]; then
    ARCHITECTURE="ARM64"
fi

# Get AWS account ID and region
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text) || { echo "Error: Failed to get AWS account ID"; exit 1; }
AWS_REGION=$(aws configure get region) || AWS_REGION="us-east-1"
echo "AWS Account ID: $ACCOUNT_ID"
echo "AWS Region: $AWS_REGION"
echo "Architecture: $ARCHITECTURE"

# Create and enter working directory
echo "Creating working directory"
WORKDIR="$(pwd)/beam-demo"
mkdir -p "$WORKDIR" || echo "Warning: Failed to create beam-demo directory"
cd "$WORKDIR" || { echo "Error: Failed to change to beam-demo directory"; exit 1; }

# Create S3 bucket for input/output data and application code
BUCKET_NAME="${ACCOUNT_ID}-beam-blog-bucket"
echo "Creating S3 bucket: $BUCKET_NAME"
aws s3 mb s3://$BUCKET_NAME --region $AWS_REGION || echo "Warning: Failed to create S3 bucket"


echo "#### 1. Initial IAM Setup ####"

# Create IAM role for EMR Serverless
echo "Creating IAM role for EMR Serverless"
cat << EOF > $WORKDIR/trust-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "emr-serverless.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

aws iam create-role --role-name beam-blog-emrserverless-role \
  --assume-role-policy-document file://$WORKDIR/trust-policy.json || echo "Warning: Failed to create IAM role"

# Create and attach S3 access policy
echo "Creating and attaching S3 access policy"
cat << EOF > $WORKDIR/s3-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:ListBucket",
        "s3:DeleteObject"
      ],
      "Resource": [
        "arn:aws:s3:::${ACCOUNT_ID}-beam-blog-bucket",
        "arn:aws:s3:::${ACCOUNT_ID}-beam-blog-bucket/*"
      ]
    }
  ]
}
EOF

aws iam put-role-policy --role-name beam-blog-emrserverless-role \
  --policy-name S3Access --policy-document file://$WORKDIR/s3-policy.json || echo "Warning: Failed to attach S3 access policy"

# Create and attach CloudWatch logs policy
echo "Creating and attaching CloudWatch logs policy"
cat << EOF > $WORKDIR/cloudwatch-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:DescribeLogGroups"
      ],
      "Resource": [
        "arn:aws:logs:${AWS_REGION}:${ACCOUNT_ID}:log-group:*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:PutLogEvents",
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:DescribeLogStreams"
      ],
      "Resource": [
        "arn:aws:logs:${AWS_REGION}:${ACCOUNT_ID}:log-group:/aws/emr-serverless/beam-blog-app:*"
      ]
    }
  ]
}
EOF

aws iam put-role-policy --role-name beam-blog-emrserverless-role \
  --policy-name CloudWatchAccess --policy-document file://$WORKDIR/cloudwatch-policy.json || echo "Warning: Failed to attach CloudWatch logs policy"

# Create and attach ECR access policy
echo "Creating and attaching ECR access policy"
cat << EOF > $WORKDIR/ecr-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:BatchCheckLayerAvailability",
        "ecr:DescribeImages",
        "ecr:GetAuthorizationToken"
      ],
      "Resource": "arn:aws:ecr:${AWS_REGION}:${ACCOUNT_ID}:repository/beam-blog-repo"
    }
  ]
}
EOF

aws iam put-role-policy --role-name beam-blog-emrserverless-role \
  --policy-name ECRAccess --policy-document file://$WORKDIR/ecr-policy.json || echo "Warning: Failed to attach ECR access policy"

echo "#### 2. Set Up Development Environment ####"

# Download example files
echo "Downloading example files"
# Download the Beam wordcount example
curl -O https://raw.githubusercontent.com/apache/beam/master/sdks/python/apache_beam/examples/wordcount.py || echo "Warning: Failed to download wordcount.py"

# Download King Lear text for processing
curl -O https://raw.githubusercontent.com/cs109/2015/master/Lectures/Lecture15b/sparklect/shakes/kinglear.txt || echo "Warning: Failed to download kinglear.txt"

# Upload King Lear text to S3
echo "Uploading King Lear text to S3"
aws s3 cp kinglear.txt s3://$BUCKET_NAME/ || echo "Warning: Failed to upload kinglear.txt to S3"

# Use Python 3.11 from pyenv
echo "Setting up Python 3.11 environment"
PYTHON_CMD="$HOME/.pyenv/versions/3.11.11/bin/python"

# Set up Python virtual environment
echo "Setting up Python virtual environment"
$PYTHON_CMD -m venv build-environment || echo "Warning: Failed to create Python virtual environment"
source build-environment/bin/activate || echo "Warning: Failed to activate Python virtual environment"

# Verify Python version
echo "Python version:"
python --version

# Install required packages
echo "Installing required packages"
python -m pip install --upgrade pip || echo "Warning: Failed to upgrade pip"
python -m pip install apache_beam==2.58.0 s3fs boto3 || echo "Warning: Failed to install required packages"

echo "#### 3. Build Custom Runtime Environment - ECR Setup ####"

# Create ECR repository
echo "Creating ECR repository"
aws ecr create-repository --repository-name beam-blog-repo --region $AWS_REGION || echo "Warning: Failed to create ECR repository"

# Set ECR repository policy
echo "Setting ECR repository policy"
aws ecr set-repository-policy \
  --repository-name beam-blog-repo \
  --region $AWS_REGION \
  --policy-text '{
    "Version": "2008-10-17",
    "Statement": [
      {
        "Sid": "allow pull and push",
        "Effect": "Allow",
        "Principal": {
          "Service": "emr-serverless.amazonaws.com"
        },
        "Action": [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:DescribeImages",
          "ecr:BatchCheckLayerAvailability"
        ]
      }
    ]
  }' --force || echo "Warning: Failed to set ECR repository policy"

# Save environment variables for later use
echo "Saving environment variables"
CONFIG_DIR="$(dirname "$(pwd)")/config"
mkdir -p $CONFIG_DIR || echo "Warning: Failed to create config directory"
cat << EOF > $CONFIG_DIR/env.sh
export ACCOUNT_ID=$ACCOUNT_ID
export AWS_REGION=$AWS_REGION
export ARCHITECTURE=$ARCHITECTURE
export BUCKET_NAME=$BUCKET_NAME
export ECR_REPO=$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/beam-blog-repo
export EMR_ROLE_ARN=arn:aws:iam::${ACCOUNT_ID}:role/beam-blog-emrserverless-role
export BEAM_DEMO_DIR=$WORKDIR
EOF

echo "Environment setup complete"