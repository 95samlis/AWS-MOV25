```bash
#!/bin/bash
set -e

# Novatrix - EC2 IAM role and S3 access

REGION="eu-north-1"
BUCKET="novatrix-data-90sali-01"
ROLE_NAME="novatrix-ec2-s3-read"
POLICY_NAME="novatrix-ec2-s3-read-policy"
PROFILE_NAME="novatrix-ec2-s3-read"
INSTANCE_ID="i-04a5c42a35df25db4"

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/${POLICY_NAME}"

echo "=== Steg 1: Kontrollera EC2-instansen ==="
aws ec2 describe-instances \
  --region "$REGION" \
  --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].State.Name' \
  --output text

echo "=== Steg 2: Skapa IAM-roll om den saknas ==="
if ! aws iam get-role --role-name "$ROLE_NAME" >/dev/null 2>&1; then
  aws iam create-role \
    --role-name "$ROLE_NAME" \
    --assume-role-policy-document '{
      "Version": "2012-10-17",
      "Statement": [{
        "Effect": "Allow",
        "Principal": {"Service": "ec2.amazonaws.com"},
        "Action": "sts:AssumeRole"
      }]
    }'
else
  echo "Rollen finns redan: $ROLE_NAME"
fi

echo "=== Steg 3: Skapa S3-policy om den saknas ==="
if ! aws iam get-policy --policy-arn "$POLICY_ARN" >/dev/null 2>&1; then
  aws iam create-policy \
    --policy-name "$POLICY_NAME" \
    --policy-document "{
      \"Version\": \"2012-10-17\",
      \"Statement\": [
        {
          \"Effect\": \"Allow\",
          \"Action\": \"s3:ListBucket\",
          \"Resource\": \"arn:aws:s3:::${BUCKET}\"
        },
        {
          \"Effect\": \"Allow\",
          \"Action\": \"s3:GetObject\",
          \"Resource\": \"arn:aws:s3:::${BUCKET}/*\"
        }
      ]
    }"
else
  echo "Policyn