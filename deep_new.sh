#!/bin/bash
set -e  # Exit on real errors

# Configuration
CLUSTER_NAME="cyderes-challenge"
REGION="us-west-2"
NODE_TYPE="t3.small"
MIN_NODES=1
MAX_NODES=2

# Function to check if resource exists
resource_exists() {
  aws $@ >/dev/null 2>&1
}

# Create or verify IAM roles
create_iam_role() {
  local role_name=$1
  local policy_arn=$2
  local trust_policy=$3

  if ! resource_exists iam get-role --role-name $role_name; then
    echo "Creating IAM role $role_name..."
    aws iam create-role \
      --role-name $role_name \
      --assume-role-policy-document "$trust_policy"
  else
    echo "IAM role $role_name already exists"
  fi

  # Attach policy if not already attached
  if ! aws iam list-attached-role-policies --role-name $role_name | grep -q $policy_arn; then
    aws iam attach-role-policy \
      --role-name $role_name \
      --policy-arn $policy_arn
  fi
}

# Create EKS Cluster Role
create_iam_role "AmazonEKSClusterRole" \
  "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy" \
  '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Service": "eks.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
      }
    ]
  }'

# Create EKS Node Role
create_iam_role "AmazonEKSNodeRole" \
  "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy" \
  '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Service": "ec2.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
      }
    ]
  }'

# Attach additional node policies
for policy in "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly" \
              "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"; do
  if ! aws iam list-attached-role-policies --role-name AmazonEKSNodeRole | grep -q $policy; then
    aws iam attach-role-policy --role-name AmazonEKSNodeRole --policy-arn $policy
  fi
done

# Check if cluster exists
if ! resource_exists eks describe-cluster --name $CLUSTER_NAME --region $REGION; then
  # Create VPC only if cluster doesn't exist
  echo "Creating VPC..."
  VPC_ID=$(aws ec2 create-vpc \
    --cidr-block 10.0.0.0/16 \
    --query 'Vpc.VpcId' \
    --output text)
  aws ec2 create-tags --resources $VPC_ID --tags Key=Name,Value=$CLUSTER_NAME

  # Create Subnets
  echo "Creating subnets..."
  PUBLIC_SUBNET=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block 10.0.1.0/24 \
    --availability-zone ${REGION}a \
    --query 'Subnet.SubnetId' \
    --output text)
  PRIVATE_SUBNET=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block 10.0.2.0/24 \
    --availability-zone ${REGION}b \
    --query 'Subnet.SubnetId' \
    --output text)

  # Tag Subnets
  aws ec2 create-tags \
    --resources $PUBLIC_SUBNET $PRIVATE_SUBNET \
    --tags \
      Key=kubernetes.io/role/elb,Value=1 \
      Key=kubernetes.io/cluster/$CLUSTER_NAME,Value=shared

  # Create Cluster
  echo "Creating EKS cluster..."
  aws eks create-cluster \
    --name $CLUSTER_NAME \
    --region $REGION \
    --role-arn $(aws iam get-role --role-name AmazonEKSClusterRole --query 'Role.Arn' --output text) \
    --resources-vpc-config subnetIds=$PUBLIC_SUBNET,$PRIVATE_SUBNET \
    --kubernetes-version 1.28

  # Wait for Cluster
  echo "Waiting for cluster to become active..."
  aws eks wait cluster-active --name $CLUSTER_NAME --region $REGION
else
  echo "Cluster $CLUSTER_NAME already exists"
  VPC_ID=$(aws eks describe-cluster --name $CLUSTER_NAME --region $REGION \
    --query 'cluster.resourcesVpcConfig.vpcId' --output text)
  SUBNETS=$(aws eks describe-cluster --name $CLUSTER_NAME --region $REGION \
    --query 'cluster.resourcesVpcConfig.subnetIds' --output text)
fi

# Check if nodegroup exists
if ! resource_exists eks describe-nodegroup --cluster-name $CLUSTER_NAME --nodegroup-name ng-spot --region $REGION; then
  echo "Creating node group..."
  aws eks create-nodegroup \
    --cluster-name $CLUSTER_NAME \
    --nodegroup-name ng-spot \
    --region $REGION \
    --subnets $(aws eks describe-cluster --name $CLUSTER_NAME --region $REGION \
      --query 'cluster.resourcesVpcConfig.subnetIds' --output text | tr ' ' ',') \
    --node-role $(aws iam get-role --role-name AmazonEKSNodeRole --query 'Role.Arn' --output text) \
    --instance-types $NODE_TYPE \
    --scaling-config minSize=$MIN_NODES,maxSize=$MAX_NODES \
    --capacity-type SPOT
else
  echo "Node group ng-spot already exists"
fi

echo "Cluster setup complete!"
echo "Configure kubectl with:"
echo "aws eks update-kubeconfig --name $CLUSTER_NAME --region $REGION"