# Blog Scripts - Apache Beam on EMR Serverless

A collection of automation scripts for setting up and running Apache Beam applications on AWS EMR Serverless. These scripts provide a complete workflow from environment setup to cleanup, designed for demonstration and blog content purposes.

## Overview

This repository contains scripts that automate the entire lifecycle of running Apache Beam applications on AWS EMR Serverless, including:

- Environment setup and AWS resource creation
- Container image building and deployment
- EMR Serverless application creation
- Pipeline execution and monitoring
- Result verification
- Resource cleanup

## Prerequisites

- AWS CLI configured with appropriate permissions
- Docker installed and running
- Bash shell environment
- AWS account with permissions for:
  - S3 bucket creation and management
  - ECR repository creation and image pushing
  - EMR Serverless application management
  - IAM role creation and management

## Project Structure

```
blogscripts/
├── scripts/
│   ├── 01_setup_env.sh          # Environment setup and S3 bucket creation
│   ├── 02_build_container.sh    # Docker container build and ECR push
│   ├── 03_create_application.sh # EMR Serverless application creation
│   ├── 04_run_pipeline.sh       # Pipeline execution
│   ├── 05_verify_results.sh     # Result verification
│   ├── 06_cleanup.sh            # Resource cleanup
│   └── run_all_timed.sh         # Execute all scripts with timing
├── config/
├── CODE_OF_CONDUCT.md
├── CONTRIBUTING.md
├── LICENSE
└── README.md
```

## Implementation

### Option 1: Run All Scripts (Recommended for Demo)

Execute all scripts in sequence with timing information:

```bash
./scripts/run_all_timed.sh
```

This will run all scripts from setup to cleanup and log execution times to `execution_times.log`.

### Option 2: Run Scripts Individually

1. **Setup Environment**
   ```bash
   ./scripts/01_setup_env.sh
   ```

2. **Build and Push Container**
   ```bash
   ./scripts/02_build_container.sh
   ```

3. **Create EMR Serverless Application**
   ```bash
   ./scripts/03_create_application.sh
   ```

4. **Run the Pipeline**
   ```bash
   ./scripts/04_run_pipeline.sh
   ```

5. **Verify Results**
   ```bash
   ./scripts/05_verify_results.sh
   ```

6. **Clean Up Resources**
   ```bash
   ./scripts/06_cleanup.sh
   ```

## Configuration

The scripts use environment variables defined in `config/env.sh`. Key variables include:

- `ACCOUNT_ID`: AWS Account ID
- `AWS_REGION`: AWS Region for resources
- `ARCHITECTURE`: System architecture (ARM64/X86_64)
- `BUCKET_NAME`: S3 bucket for data and artifacts
- `ECR_REPO`: ECR repository URL
- `EMR_ROLE_ARN`: IAM role for EMR Serverless

## What Each Script Does

### 01_setup_env.sh
- Detects system architecture
- Creates S3 bucket for data storage
- Sets up IAM roles and policies for EMR Serverless
- Creates working directory structure

### 02_build_container.sh
- Builds Docker container with Apache Beam dependencies
- Creates ECR repository
- Pushes container image to ECR

### 03_create_application.sh
- Creates EMR Serverless application
- Configures application settings based on architecture
- Sets up auto-start and auto-stop configurations

### 04_run_pipeline.sh
- Submits Apache Beam job to EMR Serverless
- Monitors job execution
- Handles job completion and error states

### 05_verify_results.sh
- Checks job execution results
- Verifies output data in S3
- Displays execution summary

### 06_cleanup.sh
- Stops and deletes EMR Serverless application
- Removes S3 bucket and contents
- Cleans up ECR repository
- Removes IAM roles and policies


## Cost Considerations

These scripts create AWS resources that may incur charges:
- S3 storage
- ECR repository storage
- EMR Serverless compute time

Remember to run the cleanup script to avoid ongoing charges.

## Contributing

Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on our code of conduct and the process for submitting pull requests.

## License

This library is licensed under the MIT-0 License. See the [LICENSE](LICENSE) file for details.

## Support

For issues and questions:
1. Check the execution logs for error details
2. Verify AWS permissions and configuration
3. Ensure all prerequisites are met
4. Review the individual script outputs for specific error messages

## Blog Series

These scripts support a blog series on running Apache Beam on AWS EMR Serverless. Each script corresponds to different sections of the tutorial content.
