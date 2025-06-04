# Cyderes DevOps Challenge

## Overview

This project provisions a Kubernetes cluster, builds and deploys a custom Nginx-based Docker image using GitHub Actions CI/CD, packages it into a Helm chart, and manages infrastructure using Terraform.

## Features

- Custom Nginx web server
- Helm chart for deployment
- GitHub Actions CI/CD workflows
- Infrastructure managed by Terraform
- Kubernetes ingress exposure
- Outputs: Cluster resources, screenshots, and proof of deployment

---

## Folder Structure

- `app/` – Static web content (served by Nginx)
- `charts/` – Helm chart for Kubernetes deployment
- `terraform/` – Terraform code for infrastructure provisioning
- `.github/workflows/` – GitHub Actions CI/CD pipelines
- `Dockerfile` – Docker build for custom Nginx webserver

## Instructions

### 1. Provision Infra
- Adjust variables in `terraform/variables.tf`
- Run GitHub Action: `.github/workflows/1-infra.yml`

### 2. Build Image
- GitHub Action builds Docker image using `Dockerfile` and pushes to Docker Hub or GitHub Container Registry.

### 3. Deploy to Kubernetes
- Helm chart deploys app using `.github/workflows/3-deploy.yml`

### 4. Output Resources
```bash
kubectl get all -A -o yaml > kubernetes_cluster_resources.yaml
