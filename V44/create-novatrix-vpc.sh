VPC_ID=$(aws ec2 create-vpc \
  --region "$REGION" \
  --cidr-block "10.0.0.0/16" \
  --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=novatrix-vpc}]' \
  --query 'Vpc.VpcId' \
  --output text)