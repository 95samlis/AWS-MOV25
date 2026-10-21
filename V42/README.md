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

<img width="1800" height="250" alt="Skärmbild 2026-10-21 000230" src="https://github.com/user-attachments/assets/fa2c0727-1390-4941-bf43-5532b216f4b7" />
<img width="400" height="300" alt="Skärmbild 2026-10-21 001028" src="https://github.com/user-attachments/assets/12f6423c-f6c2-4e03-8135-697a71cc4d1a" />
<img width="2668" height="178" alt="Skärmbild 2026-10-21 000021" src="https://github.com/user-attachments/assets/0cec1095-296c-4d1f-8839-794341c52907" />

---

## Konfigurering av säkerhetsgrupp och SSH

Jag skapade säkerhetsgruppen `novatrix-web-sg` och konfigurerade inkommande trafik så att SSH endast tillåts från min egen publika IP-adress, medan HTTP är öppet för webbplatsbesökare.

### Kommando 
Koden öppnar port 22 för SSH-anslutningar endast från min egen publika IP-adress. 


```bash
# SSH – endast min publika IP
SSH_RULE_ID="$(aws ec2 authorize-security-group-ingress \
  --group-id "$SG_ID" \
  --protocol tcp \
  --port 22 \
  --cidr "$SSH_CIDR" \
  --query 'SecurityGroupRules[0].SecurityGroupRuleId' \
  --output text \
  --region "$REGION")"


 Koden öppnar port 80 för HTTP-trafik från alla publika IPv4-adresser, så att besökare kan nå webbplatsen via internet.

# HTTP – tillgängligt för webbplatsbesökare
HTTP_RULE_ID="$(aws ec2 authorize-security-group-ingress \
  --group-id "$SG_ID" \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0 \
  --query 'SecurityGroupRules[0].SecurityGroupRuleId' \
  --output text \
  --region "$REGION")"
```


## Anslutning via SSH
Jag angav min publika IP-adress manuellt för att begränsa SSH-åtkomsten till min egen anslutning i stället för att hämta den automatiskt.

### Kommando

```bash
MY_IP="81.226.253.57"
SSH_CIDR="${MY_IP}/32"
```

### Resultat 

<img width="2266" height="162" alt="image" src="https://github.com/user-attachments/assets/a7faa36c-61ea-4043-bc23-497fe1441ec4" />


### Automatisering med userdata

Jag använde user-data.sh för att automatisera installationen av webbservern. I deploy.sh skickas filen med när EC2-instansen skapas. När instansen startar körs instruktionerna i filen, som installerar Apache, hämtar webbsidan från GitHub och startar webbservern. På så sätt slipper jag göra alla dessa steg manuellt via SSH.

## Automatisk installation med User Data

Jag använde User Data för att installera och starta Apache automatiskt när instansen skapas. Skriptet `user-data.sh` körs vid första uppstarten, så webbservern är igång utan att jag behöver ansluta via SSH.

### Kommando

Skriptet räknar ut var `deploy.sh` ligger och hittar `user-data.sh` i samma mapp. Filen skickas sedan med som User Data i `run-instances`-kommandot.

```bash
# Ange sökvägen till user-data.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_DATA="${SCRIPT_DIR}/user-data.sh"

# Skicka med User Data när instansen skapas
--user-data "file://${USER_DATA}"
```



### Kommando
Apache (`httpd`) installeras med `dnf`, och webbsidan `index.html` hämtas från GitHub till Apaches standardmapp `/var/www/html`. `--retry 5` gör att hämtningen försöks igen vid tillfälliga fel.
Jag sparade Novatrix-webbsidan i GitHub som index.html. I user-data.sh hämtas filen automatiskt och sparas i Apaches webbrot.

```bash
# Installera Apache
dnf install -y httpd

# Hämta webbsidan från GitHub
curl --fail --location --retry 5 --retry-delay 3 \
  https://raw.githubusercontent.com/95samlis/AWS-MOV25/main/V42/index.html \
  --output /var/www/html/index.html

# Starta Apache och aktivera tjänsten vid uppstart
systemctl enable --now httpd

# Kontrollera att Apache svarar lokalt
curl --fail http://localhost/ >/dev/null
```
### Deployment

Jag laddade upp `deploy.sh` och `user-data.sh` till AWS CloudShell och körde sedan `deploy.sh`. Skriptet skapade säkerhetsgruppen och EC2-instansen och skrev ut instansens publika IP-adress.
Kommandot `chmod +x deploy.sh` ger skriptet tillåtelse att köras, och `./deploy.sh` kör sedan skriptet från den aktuella katalogen.

```bash
chmod +x deploy.sh
./deploy.sh
```

### Slutresultat 

<img width="600" height="400" alt="Skärmbild 2026-10-21 023803" src="https://github.com/user-attachments/assets/73488b64-11f5-4ebd-918d-c4fb7da4a2fd" />
<img width="500" height="300" alt="Skärmbild 2026-10-21 023703" src="https://github.com/user-attachments/assets/e9218c74-5ab5-4b70-96a2-429013c25303" />

