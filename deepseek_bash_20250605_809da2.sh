#!/bin/bash

set -e

# CONFIG
CLUSTER_NAME="practice-eks"
REGION="us-west-2"
NODE_GROUP_NAME="${CLUSTER_NAME}-nodegroup"
NODE_ROLE_NAME="${CLUSTER_NAME}-node-role"
EKS_ROLE_NAME="${CLUSTER_NAME}-eks-role"
VPC_STACK_NAME="${CLUSTER_NAME}-vpc-stack"
KEY_PAIR_NAME="eks-key"
INSTANCE_TYPE="t3.small"
AMI_TYPE="AL2_x86_64"
NODE_COUNT=2

# Create key pair if it doesn't exist
aws ec2 describe-key-pairs --key-names $KEY_PAIR_NAME --region $REGION >/dev/null 2>&1 || \
aws ec2 create-key-pair --key-name $KEY_PAIR_NAME --query 'KeyMaterial' --output text --region $REGION > ${KEY_PAIR_NAME}.pem && chmod 400 ${KEY_PAIR_NAME}.pem

# Step 1: Create VPC using CloudFormation
echo "🚀 Creating VPC..."

cat > vpc.yaml <<EOF
AWSTemplateFormatVersion: '2010-09-09'
Description: EKS VPC for practice
Resources:
  VPC:
    Type: AWS::EC2::VPC
    Properties:
      CidrBlock: 10.0.0.0/16
      EnableDnsSupport: true
      EnableDnsHostnames: true
      Tags:
        - Key: Name
          Value: eks-vpc

  InternetGateway:
    Type: AWS::EC2::InternetGateway

  AttachGateway:
    Type: AWS::EC2::VPCGatewayAttachment
    Properties:
      VpcId: !Ref VPC
      InternetGatewayId: !Ref InternetGateway

  PublicSubnet1:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref VPC
      CidrBlock: 10.0.1.0/24
      MapPublicIpOnLaunch: true
      AvailabilityZone: ${REGION}a

  RouteTable:
    Type: AWS::EC2::RouteTable
    Properties:
      VpcId: !Ref VPC

  PublicRoute:
    Type: AWS::EC2::Route
    DependsOn: AttachGateway
    Properties:
      RouteTableId: !Ref RouteTable
      DestinationCidrBlock: 0.0.0.0/0
      GatewayId: !Ref InternetGateway

  SubnetRouteTableAssociation:
    Type: AWS::EC2::SubnetRouteTableAssociation
    Properties:
      SubnetId: !Ref PublicSubnet1
      RouteTableId: !Ref RouteTable
Outputs:
  VpcId:
    Value: !Ref VPC
  SubnetId:
    Value: !Ref PublicSubnet1
EOF

aws cloudformation create-stack \
  --stack-name $VPC_STACK_NAME \
  --template-body file://vpc.yaml \
  --capabilities CAPABILITY_NAMED_IAM \
  --region $REGION

echo "⏳ Waiting for VPC stack to finish..."
aws cloudformation wait stack-create-complete --stack-name $VPC_STACK_NAME --region $REGION

VPC_ID=$(aws cloudformation describe-stacks --stack-name $VPC_STACK_NAME --region $REGION --query "Stacks[0].Outputs[?OutputKey=='VpcId'].OutputValue" --output text)
SUBNET_ID=$(aws cloudformation describe-stacks --stack-name $VPC_STACK_NAME --region $REGION --query "Stacks[0].Outputs[?OutputKey=='SubnetId'].OutputValue" --output text)

# Step 2: Create EKS IAM Role
echo "🔐 Creating IAM role for EKS..."

aws iam create-role \
  --role-name $EKS_ROLE_NAME \
  --assume-role-policy-document file://<(cat <<EOF
{
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
}
EOF
)

aws iam attach-role-policy --role-name $EKS_ROLE_NAME \
  --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy

EKS_ROLE_ARN=$(aws iam get-role --role-name $EKS_ROLE_NAME --query 'Role.Arn' --output text)

# Step 3: Create the EKS Cluster
echo "📦 Creating EKS control plane..."

aws eks create-cluster \
  --name $CLUSTER_NAME \
  --region $REGION \
  --kubernetes-version "1.29" \
  --role-arn $EKS_ROLE_ARN \
  --resources-vpc-config subnetIds=$SUBNET_ID,endpointPublicAccess=true

echo "⏳ Waiting for EKS control plane to be active..."
aws eks wait cluster-active --name $CLUSTER_NAME --region $REGION

# Step 4: Create Node IAM Role
echo "🔐 Creating IAM role for EKS nodes..."

aws iam create-role \
  --role-name $NODE_ROLE_NAME \
  --assume-role-policy-document file://<(cat <<EOF
{
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
}
EOF
)

for POLICY in AmazonEKSWorkerNodePolicy AmazonEKS_CNI_Policy AmazonEC2ContainerRegistryReadOnly; do
  aws iam attach-role-policy --role-name $NODE_ROLE_NAME \
    --policy-arn arn:aws:iam::aws:policy/$POLICY
done

NODE_ROLE_ARN=$(aws iam get-role --role-name $NODE_ROLE_NAME --query 'Role.Arn' --output text)

# Step 5: Add Node Group
echo "🧱 Creating managed node group..."

aws eks create-nodegroup \
  --cluster-name $CLUSTER_NAME \
  --nodegroup-name $NODE_GROUP_NAME \
  --scaling-config minSize=1,maxSize=3,desiredSize=$NODE_COUNT \
  --disk-size 20 \
  --subnets $SUBNET_ID \
  --instance-types $INSTANCE_TYPE \
  --ami-type $AMI_TYPE \
  --node-role $NODE_ROLE_ARN \
  --region $REGION

echo "⏳ Waiting for node group to be active..."
aws eks wait nodegroup-active \
  --cluster-name $CLUSTER_NAME \
  --nodegroup-name $NODE_GROUP_NAME \
  --region $REGION

# Step 6: Update kubeconfig
aws eks update-kubeconfig --name $CLUSTER_NAME --region $REGION

echo "✅ EKS Cluster '$CLUSTER_NAME' created and ready to deploy services!"

