#!/bin/bash
set -euo pipefail

# Grundinställningar
REGION="eu-north-1"
VPC_NAME="novatrix-vpc"

# Hämtar VPC-ID för novatrix-vpc
VPC_COUNT=$(aws ec2 describe-vpcs \
  --region "$REGION" \
  --filters "Name=tag:Name,Values=$VPC_NAME" \
  --query 'length(Vpcs)' \
  --output text)

if [ "$VPC_COUNT" != "1" ]; then
  echo "Fel: Hittade inte exakt ett VPC med namnet $VPC_NAME."
  exit 1
fi

VPC_ID=$(aws ec2 describe-vpcs \
  --region "$REGION" \
  --filters "Name=tag:Name,Values=$VPC_NAME" \
  --query 'Vpcs[0].VpcId' \
  --output text)

echo "VPC: $VPC_NAME ($VPC_ID)"

# Kontrollerar att Availability Zones är tillgängliga
for AZ in eu-north-1a eu-north-1b; do
  STATE=$(aws ec2 describe-availability-zones \
    --region "$REGION" \
    --zone-names "$AZ" \
    --query 'AvailabilityZones[0].State' \
    --output text)

  if [ "$STATE" != "available" ]; then
    echo "Fel: Availability Zone $AZ är inte tillgänglig."
    exit 1
  fi
done

echo "Båda Availability Zones är tillgängliga."

# Kontrollerar att namn och CIDR-intervall inte redan används
check_subnet() {
  NAME="$1"
  CIDR="$2"

  EXISTING_NAME=$(aws ec2 describe-subnets \
    --region "$REGION" \
    --filters "Name=vpc-id,Values=$VPC_ID" \
              "Name=tag:Name,Values=$NAME" \
    --query 'Subnets[0].SubnetId' \
    --output text)

  EXISTING_CIDR=$(aws ec2 describe-subnets \
    --region "$REGION" \
    --filters "Name=vpc-id,Values=$VPC_ID" \
              "Name=cidr-block,Values=$CIDR" \
    --query 'Subnets[0].SubnetId' \
    --output text)

  if [ "$EXISTING_NAME" != "None" ] || [ "$EXISTING_CIDR" != "None" ]; then
    echo "Fel: Namnet $NAME eller CIDR $CIDR används redan."
    exit 1
  fi
}

check_subnet "novatrix-public" "10.0.1.0/24"
check_subnet "novatrix-private-a" "10.0.2.0/24"
check_subnet "novatrix-private-b" "10.0.4.0/24"

# Funktion för att skapa ett subnät
create_subnet() {
  NAME="$1"
  AZ="$2"
  CIDR="$3"
  TYPE="$4"

  echo "Skapar $NAME i $AZ med $CIDR ..."

  SUBNET_ID=$(aws ec2 create-subnet \
    --region "$REGION" \
    --vpc-id "$VPC_ID" \
    --availability-zone "$AZ" \
    --cidr-block "$CIDR" \
    --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=$NAME}]" \
    --query 'Subnet.SubnetId' \
    --output text)

  # Publikt subnät får automatisk publik IPv4
  if [ "$TYPE" = "public" ]; then
    aws ec2 modify-subnet-attribute \
      --region "$REGION" \
      --subnet-id "$SUBNET_ID" \
      --map-public-ip-on-launch
  else
    # Privata subnät får inte automatisk publik IPv4
    aws ec2 modify-subnet-attribute \
      --region "$REGION" \
      --subnet-id "$SUBNET_ID" \
      --no-map-public-ip-on-launch
  fi

  echo "$NAME skapades: $SUBNET_ID"
  echo
  echo "$SUBNET_ID"
}

# 1. Publikt subnät
SUBNET_PUBLIC_ID=$(create_subnet \
  "novatrix-public" "eu-north-1a" "10.0.1.0/24" "public")

# 2. Privat subnät A
SUBNET_PRIVATE_A_ID=$(create_subnet \
  "novatrix-private-a" "eu-north-1a" "10.0.2.0/24" "private")

# 3. Privat subnät B
SUBNET_PRIVATE_B_ID=$(create_subnet \
  "novatrix-private-b" "eu-north-1b" "10.0.4.0/24" "private")

# Slutkontroll av de tre subnäten
echo "Kontrollerar skapade subnät..."

aws ec2 describe-subnets \
  --region "$REGION" \
  --subnet-ids "$SUBNET_PUBLIC_ID" \
               "$SUBNET_PRIVATE_A_ID" \
               "$SUBNET_PRIVATE_B_ID" \
  --query 'Subnets[*].[SubnetId,AvailabilityZone,CidrBlock,MapPublicIpOnLaunch]' \
  --output table

echo "Alla tre subnäten har skapats och kontrollerats."