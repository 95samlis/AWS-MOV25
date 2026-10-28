#!/bin/bash
set -e

# Novatrix - huvudskript
# Körs från AWS CloudShell

BUCKET="novatrix-data-90sali-01"
REGION="eu-north-1"

echo "=== Steg 1: Kontrollera AWS-identitet ==="
aws sts get-caller-identity

echo "=== Steg 2: Skapa S3-bucket om den saknas ==="

if aws s3api head-bucket --bucket "$BUCKET" 2>/dev/null; then
  echo "Bucket finns redan: $BUCKET"
else
  aws s3api create-bucket \
    --bucket "$BUCKET" \
    --region "$REGION" \
    --create-bucket-configuration LocationConstraint="$REGION"
fi

echo "=== Steg 3: Blockera publik åtkomst ==="
aws s3api put-public-access-block \
  --bucket "$BUCKET" \
  --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

echo "=== Steg 4: Skapa IAM-användare och grupper ==="
bash iam-users-groups.sh

echo "=== Steg 5: Skapa IAM-policies ==="
bash iam-policies.sh

echo "=== Steg 6: Skapa EC2-roll och koppling ==="
bash ec2-roles.sh

echo "=== Novatrix setup klar ==="