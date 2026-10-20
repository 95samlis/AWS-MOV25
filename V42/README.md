# V 42 Komma igång med Compute

**Samuel Lissbro**

Det jag ska göra är att skapa en virtuell server i AWS med EC2, installera och driftsätta en webbserver för Novatrix AB.
Jag valde först att skapa och konfigurera en EC2-instans manuellt i AWS-portalen för att förstå hur miljön är uppbyggd. Jag satte även upp ett key pair som jag kan återanvända när jag bygger upp miljön på nytt. Därefter använde jag ett Bash-skript via AWS CLI i CloudShell för att automatisera skapandet av EC2-instansen och säkerhetsgruppen.

### Provisionering av en EC2-instans

Jag använde AWS CLI i CloudShell för att automatisera skapandet av en EC2-instans med Amazon Linux 2023. Jag valde instanstypen `t3.micro` för att hålla nere kostnaden och återanvände mitt befintliga key pair `nova-key`. Skriptet skapar även en säkerhetsgrupp som kopplas till instansen.

## Resurser och inställningar

| Resurs/inställning | Värde |
|--------------------|-------|
| EC2-instans | `novatrix-web` |
| Operativsystem | Amazon Linux 2023 |
| Instanstyp | `t3.micro` |
| Region | `eu-north-1` (Stockholm) |
| Key pair | `nova-key` (befintligt) |
| Security group | `novatrix-web-sg` |

## Kod från `deploy.sh` – skapande av EC2-instans

### Koden för instansen EC2

```bash
REGION="eu-north-1"
INSTANCE_NAME="novatrix-web"
SG_NAME="novatrix-web-sg"
KEY_NAME="nova-key"
INSTANCE_TYPE="t3.micro"
```

### Hämtar Amazon Linux 2023

Koden hämtar automatiskt det senaste AMI-ID:t (ett unikt ID för systemavbildningen med Amazon Linux 2023) som används för att skapa EC2-instansen.

```bash
AMI_ID="$(aws ssm get-parameter \
  --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
  --query 'Parameter.Value' \
  --output text \
  --region "$REGION")"
```

### 3. Skapar EC2-instansen

Koden skapar instansen med den valda systemavbildningen, instanstypen, nyckelparet och säkerhetsgruppen samt sparar instansens ID i variabeln INSTANCE_ID.

```bash
INSTANCE_ID="$(aws ec2 run-instances \
  --image-id "$AMI_ID" \
  --instance-type "$INSTANCE_TYPE" \
  --key-name "$KEY_NAME" \
  --security-group-ids "$SG_ID" \
  --tag-specifications \
    "ResourceType=instance,Tags=[{Key=Name,Value=${INSTANCE_NAME}}]" \
  --query 'Instances[0].InstanceId' \
  --output text \
  --region "$REGION")"
```
### Resultat 

<img width="2336" height="352" alt="Skärmbild 2026-10-21 000230" src="https://github.com/user-attachments/assets/fa2c0727-1390-4941-bf43-5532b216f4b7" />
<img width="500" height="300" alt="Skärmbild 2026-10-21 001028" src="https://github.com/user-attachments/assets/12f6423c-f6c2-4e03-8135-697a71cc4d1a" />
<img width="2668" height="178" alt="Skärmbild 2026-10-21 000021" src="https://github.com/user-attachments/assets/0cec1095-296c-4d1f-8839-794341c52907" />

