#!/bin/bash
set -euo pipefail

# Novatrix - EC2 IAM role and S3 access

REGION="eu-north-1"
BUCKET="novatrix-data-90sali-01"
ROLE_NAME="novatrix-ec2-s3-read"
POLICY_NAME="novatrix-ec2-s3-read-policy"
PROFILE_NAME="novatrix-ec2-s3-read"
INSTANCE_ID="i-04a5c42a35df25db4"

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/${POLICY_NAME}"
PROFILE_ARN="arn:aws:iam::${ACCOUNT_ID}:instance-profile/${PROFILE_NAME}"

TRUST_FILE=$(mktemp)
POLICY_FILE=$(mktemp)
trap 'rm -f "$TRUST_FILE" "$POLICY_FILE"' EXIT

cat > "$TRUST_FILE" <<'TRUST_JSON'
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
TRUST_JSON

cat > "$POLICY_FILE" <<POLICY_JSON
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "s3:ListBucket",
      "Resource": "arn:aws:s3:::${BUCKET}"
    },
    {
      "Effect": "Allow",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::${BUCKET}/*"
    }
  ]
}
POLICY_JSON

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
    --assume-role-policy-document "file://${TRUST_FILE}"
else
  echo "Rollen finns redan: $ROLE_NAME"
fi

echo "=== Steg 3: Skapa S3-policy om den saknas ==="
if ! aws iam get-policy --policy-arn "$POLICY_ARN" >/dev/null 2>&1; then
  aws iam create-policy \
    --policy-name "$POLICY_NAME" \
    --policy-document "file://${POLICY_FILE}"
else
  echo "Policyn finns redan: $POLICY_NAME"
fi

echo "=== Steg 4: Koppla policyn till rollen ==="
ATTACHED_POLICY=$(aws iam list-attached-role-policies \
  --role-name "$ROLE_NAME" \
  --query "AttachedPolicies[?PolicyArn=='${POLICY_ARN}'].PolicyArn | [0]" \
  --output text)

if [[ "$ATTACHED_POLICY" != "$POLICY_ARN" ]]; then
  aws iam attach-role-policy \
    --role-name "$ROLE_NAME" \
    --policy-arn "$POLICY_ARN"
else
  echo "Policyn är redan kopplad till rollen."
fi

echo "=== Steg 5: Skapa instance profile om den saknas ==="
if ! aws iam get-instance-profile \
  --instance-profile-name "$PROFILE_NAME" >/dev/null 2>&1; then
  aws iam create-instance-profile \
    --instance-profile-name "$PROFILE_NAME"
else
  echo "Instance profile finns redan: $PROFILE_NAME"
fi

echo "=== Steg 6: Lägg till rollen i instance profile ==="
PROFILE_ROLE=$(aws iam get-instance-profile \
  --instance-profile-name "$PROFILE_NAME" \
  --query 'InstanceProfile.Roles[0].RoleName' \
  --output text)

if [[ "$PROFILE_ROLE" == "None" || -z "$PROFILE_ROLE" ]]; then
  aws iam add-role-to-instance-profile \
    --instance-profile-name "$PROFILE_NAME" \
    --role-name "$ROLE_NAME"
elif [[ "$PROFILE_ROLE" != "$ROLE_NAME" ]]; then
  echo "FEL: Instance profile innehåller en annan roll: $PROFILE_ROLE"
  exit 1
else
  echo "Rollen finns redan i instance profile."
fi

echo "=== Steg 7: Kontrollera EC2-kopplingen ==="
INSTANCE_PROFILE_ARN=$(aws ec2 describe-instances \
  --region "$REGION" \
  --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].IamInstanceProfile.Arn' \
  --output text)

if [[ "$INSTANCE_PROFILE_ARN" == "$PROFILE_ARN" ]]; then
  echo "Rätt instance profile är redan kopplad till EC2."
elif [[ "$INSTANCE_PROFILE_ARN" != "None" && -n "$INSTANCE_PROFILE_ARN" ]]; then
  echo "FEL: En annan instance profile är kopplad: $INSTANCE_PROFILE_ARN"
  echo "Den befintliga kopplingen lämnas orörd."
  exit 1
else
  aws ec2 associate-iam-instance-profile \
    --region "$REGION" \
    --instance-id "$INSTANCE_ID" \
    --iam-instance-profile "Name=${PROFILE_NAME}"
fi

echo "=== KLAR: EC2-roll och S3-läsbehörighet har konfigurerats ==="