#!/bin/bash
set -euo pipefail

REGION="us-west-2"

# Generate timestamp suffix for unique naming
TIMESTAMP=$(date +%s)
CLUSTER_NAME="cyderes-cluster-$TIMESTAMP"
NODEGROUP_NAME="ng-ondemand-$TIMESTAMP"

echo "Using Cluster Name: $CLUSTER_NAME"
echo "Using Node Group Name: $NODEGROUP_NAME"

echo "=== IAM Setup ==="
# (IAM roles same as before, assuming these are generic roles used for all clusters)
# ...[Insert IAM role checks/creation from previous script here]...

# Fetch role ARNs (reuse existing roles)
CLUSTER_ROLE_ARN=$(aws iam get-role --role-name AmazonEKSClusterRole --query 'Role.Arn' --output text)
NODE_ROLE_ARN=$(aws iam get-role --role-name AmazonEKSNodeRole --query 'Role.Arn' --output text)

echo "=== VPC & Subnets Setup ==="

# Use new unique VPC name with timestamp
VPC_TAG_NAME="${CLUSTER_NAME}-vpc"
VPC_CIDR="10.1.0.0/16"

VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=$VPC_TAG_NAME" --query 'Vpcs[0].VpcId' --output text)
if [ "$VPC_ID" = "None" ]; then
  echo "Creating new VPC $VPC_TAG_NAME with CIDR $VPC_CIDR"
  VPC_ID=$(aws ec2 create-vpc --cidr-block $VPC_CIDR --query 'Vpc.VpcId' --output text)
  aws ec2 create-tags --resources $VPC_ID --tags Key=Name,Value=$VPC_TAG_NAME
  aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-support "{\"Value\":true}"
  aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-hostnames "{\"Value\":true}"
else
  echo "VPC $VPC_ID with tag $VPC_TAG_NAME exists"
fi

# Internet Gateway
IGW_TAG_NAME="${CLUSTER_NAME}-igw"
IGW_ID=$(aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$VPC_ID" --query 'InternetGateways[0].InternetGatewayId' --output text)
if [ "$IGW_ID" = "None" ]; then
  echo "Creating and attaching new Internet Gateway $IGW_TAG_NAME"
  IGW_ID=$(aws ec2 create-internet-gateway --query 'InternetGateway.InternetGatewayId' --output text)
  aws ec2 create-tags --resources $IGW_ID --tags Key=Name,Value=$IGW_TAG_NAME
  aws ec2 attach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID
else
  echo "Internet Gateway $IGW_ID already attached to VPC $VPC_ID"
fi

# Route Table
RTB_TAG_NAME="${CLUSTER_NAME}-rtb"
RTB_ID=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=$RTB_TAG_NAME" --query 'RouteTables[0].RouteTableId' --output text)
if [ "$RTB_ID" = "None" ]; then
  echo "Creating new route table $RTB_TAG_NAME"
  RTB_ID=$(aws ec2 create-route-table --vpc-id $VPC_ID --query 'RouteTable.RouteTableId' --output text)
  aws ec2 create-tags --resources $RTB_ID --tags Key=Name,Value=$RTB_TAG_NAME
  aws ec2 create-route --route-table-id $RTB_ID --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID
else
  echo "Route table $RTB_ID exists"
  # Ensure default route exists
  ROUTE_EXISTS=$(aws ec2 describe-route-tables --route-table-ids $RTB_ID --query "RouteTables[0].Routes[?DestinationCidrBlock=='0.0.0.0/0'] | length(@)" --output text)
  if [ "$ROUTE_EXISTS" = "0" ]; then
    echo "Adding default route to IGW $IGW_ID"
    aws ec2 create-route --route-table-id $RTB_ID --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID || true
  else
    echo "Default route to IGW exists"
  fi
fi

# Create subnets in AZ a and b, shifted CIDRs to avoid conflict
SUBNET1_TAG_NAME="${CLUSTER_NAME}-subnet-1"
SUBNET1_CIDR="10.1.1.0/24"
SUBNET1_ID=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=$SUBNET1_TAG_NAME" --query 'Subnets[0].SubnetId' --output text)
if [ "$SUBNET1_ID" = "None" ]; then
  echo "Creating subnet 1 $SUBNET1_TAG_NAME with CIDR $SUBNET1_CIDR"
  SUBNET1_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block $SUBNET1_CIDR --availability-zone ${REGION}a --query 'Subnet.SubnetId' --output text)
  aws ec2 create-tags --resources $SUBNET1_ID --tags Key=Name,Value=$SUBNET1_TAG_NAME
  aws ec2 associate-route-table --subnet-id $SUBNET1_ID --route-table-id $RTB_ID
else
  echo "Subnet 1 $SUBNET1_ID exists"
fi

SUBNET2_TAG_NAME="${CLUSTER_NAME}-subnet-2"
SUBNET2_CIDR="10.1.2.0/24"
SUBNET2_ID=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=$SUBNET2_TAG_NAME" --query 'Subnets[0].SubnetId' --output text)
if [ "$SUBNET2_ID" = "None" ]; then
  echo "Creating subnet 2 $SUBNET2_TAG_NAME with CIDR $SUBNET2_CIDR"
  SUBNET2_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block $SUBNET2_CIDR --availability-zone ${REGION}b --query 'Subnet.SubnetId' --output text)
  aws ec2 create-tags --resources $SUBNET2_ID --tags Key=Name,Value=$SUBNET2_TAG_NAME
  aws ec2 associate-route-table --subnet-id $SUBNET2_ID --route-table-id $RTB_ID
else
  echo "Subnet 2 $SUBNET2_ID exists"
fi

echo "=== Security Groups Setup ==="

CONTROL_PLANE_SG_TAG="${CLUSTER_NAME}-control-plane-sg"
CONTROL_PLANE_SG=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=$CONTROL_PLANE_SG_TAG" "Name=vpc-id,Values=$VPC_ID" --query 'SecurityGroups[0].GroupId' --output text)
if [ "$CONTROL_PLANE_SG" = "None" ]; then
  echo "Creating control plane SG $CONTROL_PLANE_SG_TAG"
  CONTROL_PLANE_SG=$(aws ec2 create-security-group --group-name $CONTROL_PLANE_SG_TAG --description "EKS control plane SG" --vpc-id $VPC_ID --query 'GroupId' --output text)
  aws ec2 authorize-security-group-ingress --group-id $CONTROL_PLANE_SG --protocol tcp --port 443 --cidr 0.0.0.0/0
else
  echo "Control Plane SG $CONTROL_PLANE_SG exists"
fi

NODEGROUP_SG_TAG="${CLUSTER_NAME}-nodegroup-sg"
NODEGROUP_SG=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=$NODEGROUP_SG_TAG" "Name=vpc-id,Values=$VPC_ID" --query 'SecurityGroups[0].GroupId' --output text)
if [ "$NODEGROUP_SG" = "None" ]; then
  echo "Creating node group SG $NODEGROUP_SG_TAG"
  NODEGROUP_SG=$(aws ec2 create-security-group --group-name $NODEGROUP_SG_TAG --description "EKS node group SG" --vpc-id $VPC_ID --query 'GroupId' --output text)
  aws ec2 authorize-security-group-ingress --group-id $NODEGROUP_SG --protocol tcp --port 443 --source-group $CONTROL_PLANE_SG
  aws ec2 authorize-security-group-ingress --group-id $NODEGROUP_SG --protocol -1 --source-group $NODEGROUP_SG
  aws ec2 authorize-security-group-egress --group-id $NODEGROUP_SG --protocol -1 --cidr 0.0.0.0/0
else
  echo "Node Group SG $NODEGROUP_SG exists"
fi

echo "=== Creating EKS Cluster ==="

CLUSTER_EXISTS=$(aws eks describe-cluster --name $CLUSTER_NAME --region $REGION --query 'cluster.status' --output text 2>/dev/null || echo "MISSING")
if [ "$CLUSTER_EXISTS" != "MISSING" ]; then
  echo "Cluster $CLUSTER_NAME already exists with status $CLUSTER_EXISTS"
else
  echo "Creating cluster $CLUSTER_NAME..."
  aws eks create-cluster \
    --name $CLUSTER_NAME \
    --region $REGION \
    --role-arn $CLUSTER_ROLE_ARN \
    --resources-vpc-config subnetIds=$SUBNET1_ID,$SUBNET2_ID,securityGroupIds=$CONTROL_PLANE_SG \
    --kubernetes-version 1.28
fi

echo "Waiting for cluster to become ACTIVE..."
aws eks wait cluster-active --name $CLUSTER_NAME --region $REGION

echo "=== Creating EKS Node Group ==="

NODEGROUP_EXISTS=$(aws eks describe-nodegroup --cluster-name $CLUSTER_NAME --nodegroup-name $NODEGROUP_NAME --region $REGION --query 'nodegroup.status' --output text 2>/dev/null || echo "MISSING")
if [ "$NODEGROUP_EXISTS" != "MISSING" ]; then
  echo "Node group $NODEGROUP_NAME already exists with status $NODEGROUP_EXISTS"
else
  echo "Creating node group $NODEGROUP_NAME..."
  aws eks create-nodegroup \
    --cluster-name $CLUSTER_NAME \
    --nodegroup-name $NODEGROUP_NAME \
    --region $REGION \
    --node-role $NODE_ROLE_ARN \
    --subnets $SUBNET1_ID $SUBNET2_ID \
    --scaling-config minSize=1,maxSize=2,desiredSize=1 \
    --instance-types t3.small \
    --disk-size 20 \
    --ami-type AL2_x86_64 \
    --remote-access ec2SshKey=your-key-name \
    --labels environment=dev \
    --tags Name=$NODEGROUP_NAME
fi

echo "Done!"
