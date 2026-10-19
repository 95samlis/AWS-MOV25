#!/bin/bash
set -Eeuo pipefail

# Novatrix – AWS Uppgift 1, vecka 42

REGION="eu-north-1"
INSTANCE_NAME="novatrix-web"
SG_NAME="novatrix-web-sg"
KEY_NAME="nova-key"
INSTANCE_TYPE="t3.micro"

# Din personliga publika IP för SSH
MY_IP="81.226.253.57"
SSH_CIDR="${MY_IP}/32"

# Webbplatsen som publiceras
WEBSITE_URL="https://raw.githubusercontent.com/95samlis/AWS-MOV25/main/V42/index.html"

# Hitta katalogen där deploy.sh ligger
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_DATA="${SCRIPT_DIR}/user-data.sh"

echo "Kontrollerar förutsättningarna..."

# Kontrollera AWS CLI
aws sts get-caller-identity --region "$REGION" >/dev/null

# Kontrollera User Data-filen
if [[ ! -f "$USER_DATA" ]]; then
  echo "FEL: user-data.sh saknas i ${SCRIPT_DIR}"
  exit 1
fi

# Kontrollera att filen börjar med shebang utan inledande radbrytning
if [[ "$(head -c 2 "$USER_DATA")" != '#!' ]]; then
  echo "FEL: user-data.sh måste börja direkt med #!/bin/bash."
  exit 1
fi

# Avbryt vid Windows-radbrytningar
if grep -q $'\r' "$USER_DATA"; then
  echo "FEL: user-data.sh innehåller Windows-radbrytningar."
  echo "Konvertera filen till Unix-radbrytningar (LF)."
  exit 1
fi

# Kontrollera att rätt webbplats anges i User Data
if ! grep -Fq "$WEBSITE_URL" "$USER_DATA"; then
  echo "FEL: GitHub-URL:en i user-data.sh stämmer inte."
  exit 1
fi

# Kontrollera att webbplatsen går att hämta
curl -fsSL "$WEBSITE_URL" -o /dev/null

# Kontrollera att nyckelparet finns i Stockholm
aws ec2 describe-key-pairs \
  --key-names "$KEY_NAME" \
  --region "$REGION" >/dev/null

# Hämta standard-VPC
VPC_ID="$(aws ec2 describe-vpcs \
  --filters Name=isDefault,Values=true \
  --query 'Vpcs[0].VpcId' \
  --output text \
  --region "$REGION")"

if [[ "$VPC_ID" == "None" || -z "$VPC_ID" ]]; then
  echo "FEL: Ingen standard-VPC hittades i ${REGION}"
  exit 1
fi

# Avbryt om en instans med samma namn redan finns
EXISTING_INSTANCE="$(aws ec2 describe-instances \
  --filters \
    "Name=tag:Name,Values=${INSTANCE_NAME}" \
    "Name=instance-state-name,Values=pending,running,stopping,stopped" \
  --query 'Reservations[].Instances[].InstanceId' \
  --output text \
  --region "$REGION")"

if [[ -n "$EXISTING_INSTANCE" && "$EXISTING_INSTANCE" != "None" ]]; then
  echo "FEL: En instans med namnet ${INSTANCE_NAME} finns redan:"
  echo "$EXISTING_INSTANCE"
  echo "Avbryter för att undvika dubbla instanser."
  exit 1
fi

# Avbryt om säkerhetsgruppen redan finns
EXISTING_SG="$(aws ec2 describe-security-groups \
  --filters \
    "Name=group-name,Values=${SG_NAME}" \
    "Name=vpc-id,Values=${VPC_ID}" \
  --query 'SecurityGroups[0].GroupId' \
  --output text \
  --region "$REGION")"

if [[ "$EXISTING_SG" != "None" && -n "$EXISTING_SG" ]]; then
  echo "FEL: Säkerhetsgruppen ${SG_NAME} finns redan: ${EXISTING_SG}"
  echo "Avbryter för att undvika dubbla resurser."
  exit 1
fi

echo "Region: $REGION"
echo "Instansnamn: $INSTANCE_NAME"
echo "Instanstyp: $INSTANCE_TYPE"
echo "Nyckelpar: $KEY_NAME"
echo "SSH tillåts från: $SSH_CIDR"
echo "Webbplats: $WEBSITE_URL"

# Skapa säkerhetsgruppen
SG_ID="$(aws ec2 create-security-group \
  --group-name "$SG_NAME" \
  --description "Novatrix web server security group" \
  --vpc-id "$VPC_ID" \
  --tag-specifications \
    "ResourceType=security-group,Tags=[{Key=Name,Value=${SG_NAME}}]" \
  --query 'GroupId' \
  --output text \
  --region "$REGION")"

echo "Skapade säkerhetsgrupp: $SG_ID"

# SSH – endast din personliga IP
SSH_RULE_ID="$(aws ec2 authorize-security-group-ingress \
  --group-id "$SG_ID" \
  --protocol tcp \
  --port 22 \
  --cidr "$SSH_CIDR" \
  --query 'SecurityGroupRules[0].SecurityGroupRuleId' \
  --output text \
  --region "$REGION")"

# HTTP – tillgängligt för webbplatsbesökare
HTTP_RULE_ID="$(aws ec2 authorize-security-group-ingress \
  --group-id "$SG_ID" \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0 \
  --query 'SecurityGroupRules[0].SecurityGroupRuleId' \
  --output text \
  --region "$REGION")"

# Namnge varje regel separat
aws ec2 create-tags \
  --resources "$SSH_RULE_ID" \
  --tags "Key=Name,Value=SSH - My IP" \
  --region "$REGION"

aws ec2 create-tags \
  --resources "$HTTP_RULE_ID" \
  --tags "Key=Name,Value=HTTP - Website" \
  --region "$REGION"

# Hämta senaste Amazon Linux 2023 AMI för x86-64
AMI_ID="$(aws ssm get-parameter \
  --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
  --query 'Parameter.Value' \
  --output text \
  --region "$REGION")"

echo "Skapar EC2-instansen..."

# Skapa instansen och skicka User Data
INSTANCE_ID="$(aws ec2 run-instances \
  --image-id "$AMI_ID" \
  --instance-type "$INSTANCE_TYPE" \
  --key-name "$KEY_NAME" \
  --security-group-ids "$SG_ID" \
  --user-data "file://${USER_DATA}" \
  --tag-specifications \
    "ResourceType=instance,Tags=[{Key=Name,Value=${INSTANCE_NAME}}]" \
  --query 'Instances[0].InstanceId' \
  --output text \
  --region "$REGION")"

echo "Instans skapad: $INSTANCE_ID"
echo "Väntar på att instansen startar..."

aws ec2 wait instance-running \
  --instance-ids "$INSTANCE_ID" \
  --region "$REGION"

# Vänta tills AWS statuskontroller är klara
aws ec2 wait instance-status-ok \
  --instance-ids "$INSTANCE_ID" \
  --region "$REGION"

PUBLIC_IP="$(aws ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text \
  --region "$REGION")"

echo ""
echo "EC2-instansen är igång."
echo "Instance ID: $INSTANCE_ID"
echo "Security Group: $SG_ID"
echo "Publik IP: $PUBLIC_IP"
echo "Webbplats: http://${PUBLIC_IP}"
echo ""
echo "OBS: Kontrollera att User Data har slutförts innan du testar webbplatsen."

#senaste