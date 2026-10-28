```bash
#!/bin/bash
set -e

# Novatrix - IAM policies

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION="eu-north-1"
BUCKET="novatrix-data-90sali-01"
INSTANCE_ID="i-04a5c42a35df25db4"

DEV_POLICY="novatrix-utveckling-s3"
DRIFT_POLICY="novatrix-drift-ec2"

# 1. Skapa policy för Utveckling: S3-objekt
DEV_POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/${DEV_POLICY}"

if ! aws iam get-policy --policy-arn "$DEV_POLICY_ARN" >/dev/null 2>&1; then
  aws iam create-policy \
    --policy-name "$DEV_POLICY" \
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
          \"Action\": [
            \"s3:GetObject\",
            \"s3:PutObject\",
            \"s3:DeleteObject\"
          ],
          \"Resource\": \"arn:aws:s3:::${BUCKET}/*\"
        }
      ]
    }"
fi

# 2. Skapa policy för Drift: EC2
DRIFT_POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/${DRIFT_POLICY}"

if ! aws iam get-policy --policy-arn "$DRIFT_POLICY_ARN" >/dev/null 2>&1; then
  aws iam create-policy \
    --policy-name "$DRIFT_POLICY" \
    --policy-document "{
      \"Version\": \"2012-10-17\",
      \"Statement\": [
        {
          \"Effect\": \"Allow\",
          \"Action\": \"ec2:DescribeInstances\",
          \"Resource\": \"*\"
        },
        {
          \"Effect\": \"Allow\",
          \"Action\": [
            \"ec2:StartInstances\",
            \"ec2:StopInstances\"
          ],
          \"Resource\": \"arn:aws:ec2:${REGION}:${ACCOUNT_ID}:instance/${INSTANCE_ID}\"
        }
      ]
    }"
fi

# 3. Koppla policies till IAM-grupperna
aws iam attach-group-policy \
  --group-name Utveckling \
  --policy-arn "$DEV_POLICY_ARN"

aws iam attach-group-policy \
  --group-name Drift \
  --policy-arn "$DRIFT_POLICY_ARN"

echo "Novatrix IAM policies har skapats och kopplats till grupperna."
```