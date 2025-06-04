# Cyderes DevOps Challenge Solution

This repository contains the solution for the Cyderes DevOps Engineer challenge.

## Solution Overview

The solution includes:
1. A Dockerized NGINX web server with a custom index page
2. Helm charts for deploying the web server to Kubernetes
3. Terraform code for provisioning AWS resources (ECR repository)
4. GitHub Actions workflows for CI/CD

## Prerequisites

- AWS account with EKS and ECR access
- kubectl configured to access the EKS cluster
- Terraform installed
- Helm installed

## Setup Instructions

1. Clone this repository
2. Configure AWS credentials
3. Run Terraform to provision infrastructure:
   ```bash
   cd terraform
   terraform init
   terraform apply