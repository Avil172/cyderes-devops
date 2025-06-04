# Cyderes DevOps Challenge - EKS Deployment

This solution deploys a Kubernetes cluster on AWS EKS with:
- Terraform for infrastructure provisioning
- Helm for application deployment
- GitHub Actions for CI/CD pipelines

## Architecture

![Architecture Diagram](screenshots/architecture.png)

## Prerequisites

1. AWS account with IAM permissions
2. GitHub repository secrets configured:
   - `AWS_IAM_ROLE`: ARN of IAM role for GitHub Actions
3. S3 bucket and DynamoDB table for Terraform state

## Deployment Workflows

1. **Infrastructure Provisioning**:
   - Creates EKS cluster, VPC, and ECR repository
   - Triggered manually via GitHub Actions

2. **Docker Image Build**:
   - Builds and pushes NGINX image to ECR
   - Triggered on changes to `app/` or `Dockerfile`

3. **Helm Deployment**:
   - Deploys webserver to EKS cluster
   - Triggered on changes to `charts/`

## Accessing the Application

After deployment, get the LoadBalancer URL:
```bash
kubectl get svc -n webserver