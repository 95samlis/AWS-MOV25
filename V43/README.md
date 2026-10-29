## V43 – IAM och identitet

**SAMUEL LISSBRO**

### Syfte 

Syftet med uppgiften är att konfigurera IAM i AWS för att styra vilka användare, grupper och tjänster som får åtkomst till olika resurser. 
Med hjälp av policies och roller tillämpas principen om least privilege, vilket innebär att varje användare och tjänst endast får de behörigheter som behövs.

## Översikt över IAM-behörigheter

| Identitet | Resurs | Behörigheter | Syfte |
|---|---|---|---|
| dev-erik | S3-bucket | Lista, läsa, ladda upp och radera objekt | Hantera utvecklingsfiler |
| drift-david | EC2-instans | Visa instanser, starta och stoppa en specifik instans | Hantera drift |
| novatrix-ec2-s3-read | S3-bucket | Lista och läsa objekt | Låta EC2 läsa filer från S3 |

**Princip:** Varje identitet får endast de behörigheter som behövs för dess uppgift. Användarna får sina behörigheter via IAM-grupper, medan EC2 får åtkomst genom en IAM-roll.

--- 

## Användare och grupper

Jag skapade två IAM-grupper, `Utveckling` och `Drift`, samt två användare som representerar respektive arbetsområde. Användarna placerades i rätt grupp för att behörigheter senare ska kunna tilldelas via grupperna.

**Skapa grupper och användare:**

```bash
aws iam create-group --group-name Utveckling
aws iam create-group --group-name Drift

aws iam create-user --user-name dev-erik
aws iam create-user --user-name drift-david
```

**Koppla användarna till grupperna:**

```bash
aws iam add-user-to-group \
  --user-name dev-erik \
  --group-name Utveckling

aws iam add-user-to-group \
  --user-name drift-david \
  --group-name Drift
```

Det fullständiga skriptet finns i `iam-users-groups.sh`. Skriptet kontrollerar om grupper och användare redan finns innan de skapas.

### Verifiering

<img width="1846" height="196" alt="image" src="https://github.com/user-attachments/assets/b285713e-2fc1-47c5-b23e-42dab7439b0a" />

<img width="1946" height="186" alt="image" src="https://github.com/user-attachments/assets/6a4c156d-6d63-47a2-bc31-3b23de2bb774" />


---

## Policies enligt least privilege

Policyn `novatrix-drift-ec2` ger gruppen `Drift` rätt att visa EC2-instanser och starta eller stoppa en specifik instans.

Policyn `novatrix-utveckling-s3` ger gruppen `Utveckling` rätt att lista, läsa, ladda upp och radera filer i S3-bucketen.

**Utveckling – S3**

Koden visar vilka saker gruppen får göra med filer i S3.

```json
"Action": [
  "s3:GetObject",
  "s3:PutObject",
  "s3:DeleteObject"
],
"Resource": "arn:aws:s3:::novatrix-data-90sali-01/*"
```

**Drift – EC2**

Koden visar att gruppen får starta och stoppa den valda EC2-instansen.

```json
"Action": [
  "ec2:StartInstances",
  "ec2:StopInstances"
],
"Resource": "arn:aws:ec2:eu-north-1:017636909046:instance/i-04a5c42a35df25db4"
```

**Koppla policies till grupper**

Kommandona kopplar rätt policy till rätt grupp.

```bash
aws iam attach-group-policy \
  --group-name Utveckling \
  --policy-arn "$DEV_POLICY_ARN"

aws iam attach-group-policy \
  --group-name Drift \
  --policy-arn "$DRIFT_POLICY_ARN"
```

**Hela skriptet:** `iam-policies.sh`

### Verifiering

Bilderna visar vilka behörigheter som tilldelats grupperna Utveckling och Drift samt att åtkomsten är begränsad till rätt AWS-resurser.

**Utveckling – S3**

<img width="1526" height="152" alt="Skärmbild 2026-10-29 124820" src="https://github.com/user-attachments/assets/55fff0f6-0010-4327-8a63-641c1e7c9056" />

<img width="1586" height="210" alt="Skärmbild 2026-10-29 124758" src="https://github.com/user-attachments/assets/39d1ff35-35da-437c-b8aa-e8509ae4830f" />

**Drift – EC2**

<img width="1536" height="226" alt="Skärmbild 2026-10-29 124713" src="https://github.com/user-attachments/assets/2c0322a7-9165-4d5b-981f-cd369811eb05" />
<img width="1568" height="200" alt="Skärmbild 2026-10-29 124621" src="https://github.com/user-attachments/assets/f18d5cc2-a59f-4814-a84c-81c1156f021b" />

---

## Behörigheter mellan tjänster

Jag skapade IAM-rollen `novatrix-ec2-s3-read` så att EC2-instansen kan läsa filer från S3. På så sätt behöver servern inga egna åtkomstnycklar.

**1. IAM-roll och behörighet**
Rollen tillåter EC2 att använda den. Policyn ger rätt att lista innehållet i S3-bucketen och läsa objekt.

```json
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
```

**2. S3-policy**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "s3:ListBucket",
      "Resource": "arn:aws:s3:::novatrix-data-90sali-01"
    },
    {
      "Effect": "Allow",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::novatrix-data-90sali-01/*"
    }
  ]
}
```

**3. Koppla rollen till EC2**

Skriptet skapar en instance profile, lägger IAM-rollen i den och kopplar profilen till EC2-instansen.

```bash
aws ec2 associate-iam-instance-profile \
  --region "$REGION" \
  --instance-id "$INSTANCE_ID" \
  --iam-instance-profile "Name=${PROFILE_NAME}"
```

Hela skriptet finns i `ec2-roles.sh`.

**Motivering:** EC2 får bara lista och läsa från den angivna S3-bucketen. Det följer least privilege och begränsar åtkomsten till det som servern behöver.

**Verifiering**

Jag använde följande kommandon på EC2-instansen för att kontrollera rollen och testa åtkomsten till S3.

```bash
aws sts get-caller-identity
aws s3 ls s3://novatrix-data-90sali-01/
```


**Bild 1 – Verifiering av IAM-roll:**  

Kommandot `aws sts get-caller-identity` visar att EC2-instansen använder rollen `novatrix-ec2-s3-read`.

<img width="1516" height="268" alt="ec2-iam-role" src="https://github.com/user-attachments/assets/0297c679-f734-464d-adea-7341a7a58afc" />


Bilderna visar att EC2 använder IAM-rollen `novatrix-ec2-s3-read` och kan lista filer i S3-bucketen. Policyn begränsar åtkomsten till att lista och läsa objekt i den angivna bucketen.

**S3-policy:**

<img width="864" height="648" alt="Verijson" src="https://github.com/user-attachments/assets/6b2a2a6b-5351-4d88-82ed-1819cd18e251" />


**Test från EC2:**

<img width="1448" height="324" alt="veri 2" src="https://github.com/user-attachments/assets/34769adf-bed9-4385-9d6c-3e7aa3895b7f" />


**Motivering**

EC2 får endast läsa från den aktuella S3-bucketen. Det begränsar åtkomsten till det som servern behöver och följer principen least privilege.

---

### Verifiering av IAM-behörigheter för Drift och Utveckling


Jag testade användaren `drift-david` i AWS-portalen. Han kunde stoppa EC2-instansen `novatrix-web`, men fick inte åtkomst till S3-bucketen.

<img width="1750" height="486" alt="david drift-instans" src="https://github.com/user-attachments/assets/7ce086a8-c733-4eec-a0bb-29e81d6b1fbf" />
<img width="1492" height="750" alt="drift david-denied" src="https://github.com/user-attachments/assets/9d082697-c708-4ddf-a47f-d4ccee148d68" />


**Motivering:** Drift ska kunna starta och stoppa servern vid behov, men behöver inte hantera filer i S3. Därför får användaren bara de behörigheter som behövs för driftarbetet.

## Test av användaren `dev-erik`

Jag testade användaren `dev-erik` i AWS-portalen. Han kunde se filerna i S3-bucketen och ladda upp en fil, men nekades åtkomst till EC2.

<img width="1370" height="672" alt="erik nekad" src="https://github.com/user-attachments/assets/77c645f2-4f29-4fc0-b341-672c02f3fdce" />
<img width="1634" height="678" alt="dev-erik s3 1" src="https://github.com/user-attachments/assets/3938abcd-976b-4dc9-a7fa-973f7635cac6" />
<img width="1630" height="210" alt="dev-erik uppladdning" src="https://github.com/user-attachments/assets/87e65a6a-72fd-4958-b250-eb050a85e80c" />

**Motivering:** Utveckling behöver kunna läsa och hantera filer i S3 för sitt arbete, men behöver inte starta eller stoppa servrar. Därför har användaren S3-behörigheter men inte EC2-behörigheter. Det följer principen least privilege.

