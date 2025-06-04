#!/bin/bash
set -e  # Exit on error

# 1. Get LoadBalancer security group ID
LB_HOSTNAME=$(kubectl get svc webserver-webserver -n cyderes -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
LB_SG=$(aws elbv2 describe-load-balancers \
  --query "LoadBalancers[?DNSName=='$LB_HOSTNAME'].SecurityGroups[0]" \
  --output text)

# 2. Add HTTP access (idempotent operation)
aws ec2 authorize-security-group-ingress \
  --group-id "$LB_SG" \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0 2>/dev/null || true

# 3. Verify rules
echo -e "\nCurrent Security Group Rules:"
aws ec2 describe-security-groups \
  --group-ids "$LB_SG" \
  --query "SecurityGroups[0].IpPermissions[?FromPort==\`80\`]" \
  --output table

# 4. Test connection
echo -e "\nTesting LoadBalancer ($LB_HOSTNAME)..."
curl --connect-timeout 10 -svo /dev/null "http://$LB_HOSTNAME" 2>&1 | grep -E 'HTTP/|< title'
