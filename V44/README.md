# Novatrix – Nätverksdokumentation (AWS)

Dokumentation över hur nätverket för Novatrix byggdes upp i AWS, region `eu-north-1`. Principen: **nätverk först, säkerhet sedan.**

## Innehåll

1. [Översikt](#översikt)
2. [VPC](#1-vpc--novatrix-vpc)
3. [Subnät och Availability Zones](#2-subnät-och-availability-zones)
4. [Internet Gateway och Route Table](#3-internet-gateway-och-route-table)
5. [Security Group](#4-security-group--novatrix-web-sg)
6. [AMI](#5-skapa-ami--novatrix-web-v44)
7. [EC2-instans i publikt subnät](#6-starta-novatrix-web-i-novatrix-public)
8. [Network ACL](#7-network-acl--novatrix-public-nacl)

---

## Översikt

| Komponent | Syfte |
|---|---|
| **VPC** | Hela nätverket med sin adressrymd |
| **Subnät** | Publika och privata delar av nätverket, var och en med sin adressbit |
| **Internet Gateway** | Ger VPC:et en väg ut mot internet |
| **Route tables** | Avgör vilka subnät som når internet |
| **Resurser** | Ligger i subnät och får privata IP-adresser därifrån |

---

## 1. VPC – `novatrix-vpc`

Första steget är att skapa ett VPC. Det är det yttersta lagret, och inuti det placeras alla subnät, gateways och resurser.

```bash
# Skapar ett nytt VPC med namnet novatrix-vpc i regionen eu-north-1.
# VPC:et tilldelas IPv4-adressutrymmet 10.0.0.0/16.
# Endast IPv4 används – IPv6 aktiveras inte.
# Det skapade VPC-ID:t sparas i variabeln VPC_ID.
# Inga subnät eller gateways skapas i detta steg.

VPC_ID=$(aws ec2 create-vpc \
  --region "$REGION" \
  --cidr-block "10.0.0.0/16" \
  --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=novatrix-vpc}]' \
  --query 'Vpc.VpcId' \
  --output text)
```

| Inställning | Värde |
|---|---|
| Namn | `novatrix-vpc` |
| Region | `eu-north-1` |
| IPv4 CIDR | `10.0.0.0/16` |
| IPv6 | Inte aktiverat |

### Verifiering 

<img width="2508" height="88" alt="image" src="https://github.com/user-attachments/assets/b3eb121a-0cca-4aca-be28-350fa2b74225" />


---

## 2. Subnät och Availability Zones

Tre subnät skapades i `novatrix-vpc`. Syftet är att dela upp nätverket i ett publikt och två privata subnät.

| Subnät | Typ | Availability Zone | CIDR | Användning |
|---|---|---|---|---|
| `novatrix-public` | Publikt | `eu-north-1a` | `10.0.1.0/24` | Resurser som ska nås från internet, t.ex. en webbserver |
| `novatrix-private-a` | Privat | `eu-north-1a` | `10.0.2.0/24` | Interna resurser som inte ska vara direkt åtkomliga från internet |
| `novatrix-private-b` | Privat | `eu-north-1b` | `10.0.4.0/24` | Interna resurser i en annan tillgänglighetszon |

> [!NOTE]
> De två privata subnäten ligger i olika Availability Zones. Det ger möjlighet till redundans: om en zon får problem kan resurser i den andra zonen fortsätta att fungera, om systemet är konfigurerat för det.

### Skapa subnäten

```bash
# Skapar publikt subnät
create_subnet \
  "novatrix-public" "eu-north-1a" "10.0.1.0/24" "public"

# Skapar privat subnät A
create_subnet \
  "novatrix-private-a" "eu-north-1a" "10.0.2.0/24" "private"

# Skapar privat subnät B i en annan zon
create_subnet \
  "novatrix-private-b" "eu-north-1b" "10.0.4.0/24" "private"
```

Det publika subnätet får automatisk tilldelning av publik IPv4-adress. Den funktionen är avstängd för de privata subnäten.

### Verifiering

<img width="2574" height="154" alt="image" src="https://github.com/user-attachments/assets/47070499-97d9-46f9-98d2-6eafa57b4187" />


### Filreferens

Hela skriptet finns i GitHub-repositoryt: [`create-novatrix-subnets.sh`](./create-novatrix-subnets.sh)

Skriptet innehåller även kontroller av VPC och tillgänglighetszoner samt en kontroll av att subnäten har skapats med rätt inställningar.

---

## 3. Internet Gateway och Route Table

### Internet Gateway – `novatrix-igw`

En Internet Gateway skapades via AWS-portalen och kopplades till VPC:et `novatrix-vpc`.

**Syfte:** Ge VPC:et en anslutning till internet så att nätverkstrafik kan skickas ut och tas emot.

### Route Table – `novatrix-public-rt`

En route table skapades via AWS-portalen och kopplades till `novatrix-vpc`.

**Syfte:** Styra trafiken från det publika subnätet mot internet.

Under **Edit routes** lades följande regel till:

| Destination | Target |
|---|---|
| `0.0.0.0/0` | Internet Gateway `novatrix-igw` |

Regeln innebär att all IPv4-trafik som inte har en annan, mer specifik route skickas vidare till Internet Gateway.

### Subnet association

Under **Subnet associations → Edit** valdes `novatrix-public` och kopplades till `novatrix-public-rt`. Det ger det publika subnätet en väg till internet via Internet Gateway.

<img width="1718" height="182" alt="image" src="https://github.com/user-attachments/assets/3f4ca383-3885-4c79-9eb0-03ee9a193900" />

<img width="2478" height="202" alt="image" src="https://github.com/user-attachments/assets/a1353a8f-0864-450b-8afb-1c8859ff241f" />

---

## 4. Security Group – `novatrix-web-sg`

En Security Group skapades via EC2 och kopplades till `novatrix-vpc`.

### Inkommande regler

| Typ | Port | Källa |
|---|---|---|
| HTTP | 80 | Anywhere (`0.0.0.0/0`) |
| HTTPS | 443 | Anywhere (`0.0.0.0/0`) |
| SSH | 22 | My IP |

**Syfte:** Webbservern ska vara tillgänglig via HTTP och HTTPS, medan administrativ åtkomst via SSH endast tillåts från min egen IP-adress.

### Verifiering

<img width="2138" height="56" alt="image" src="https://github.com/user-attachments/assets/5180aa15-29a8-4259-a47f-d9bd9a098ddf" />


<img width="2030" height="282" alt="Skärmbild 2026-11-03 220144" src="https://github.com/user-attachments/assets/51bf3bff-f157-4a73-9d43-c8da2ebc8997" />

---

## 5. Skapa AMI – `novatrix-web-v44`

Den befintliga EC2-instansen `novatrix-web` döptes om till `novatrix-web-gammal` för att skilja den från den nya servern.

Därefter skapades en AMI via **Actions → Create image** med namnet `novatrix-web-v44`.

**Syfte:** AMI:n fungerar som en mall för att skapa en ny EC2-instans med samma serverinnehåll, utan att behöva konfigurera servern från början.

Den skapade AMI:n finns under **EC2 → AMIs → Images**.

<img width="2640" height="96" alt="image" src="https://github.com/user-attachments/assets/df31d9af-cac9-4f92-945d-0865013a42ea" />

<img width="2698" height="152" alt="imageinstans01" src="https://github.com/user-attachments/assets/18e708a4-7622-4692-85fc-5893705d31fd" />


---

## 6. Starta `novatrix-web` i `novatrix-public`

Den nya webbservern startades från AMI:n `novatrix-web-v44`.

| Inställning | Värde |
|---|---|
| Instance name | `novatrix-web` |
| AMI | `novatrix-web-v44` |
| Instance type | `t3.micro` |
| Key pair | `nova-key` |
| VPC | `novatrix-vpc` |
| Subnet | `novatrix-public` |
| Auto-assign public IP | Enabled |
| Security Group | `novatrix-web-sg` |
| IAM Role | `novatrix-ec2-read` |

**Syfte:** Skapa en ny webbserver i det publika subnätet med samma serverinnehåll som originalet.

- Den **publika IP-adressen** gör webbservern nåbar via internet.
- **Security Group** styr tillåten trafik.
- **IAM-rollen** ger servern behörighet att läsa från S3-bucketen.

<img width="2698" height="152" alt="imageinstans01" src="https://github.com/user-attachments/assets/fc77ba6a-7e58-4488-9786-3f418b8c9642" />

<img width="2330" height="124" alt="image" src="https://github.com/user-attachments/assets/2e82204a-42e9-440b-b721-6869e6b1a963" />

---

## 7. Network ACL – `novatrix-public-nacl`

En Network ACL skapades via **VPC → Network ACLs** med namnet `novatrix-public-nacl` och kopplades till `novatrix-vpc`.

> [!IMPORTANT]
> En ny NACL nekar all trafik som standard. Därför lades följande regler till.

### Inbound rules – inkommande trafik

| Regel | Typ | Protokoll | Port | Källa | Syfte |
|---|---|---|---|---|---|
| 100 | HTTP | TCP | 80 | `0.0.0.0/0` | Besökare når webbservern via HTTP |
| 110 | HTTPS | TCP | 443 | `0.0.0.0/0` | Besökare når webbservern via HTTPS |
| 120 | SSH | TCP | 22 | `81.226.253.57/32` | Administrativ åtkomst, endast från min IP |
| 130 | Custom TCP | TCP | 1024–65535 | `0.0.0.0/0` | Svar från externa tjänster när webbservern själv initierar anslutningar |

### Outbound rules – utgående trafik

| Regel | Typ | Protokoll | Port | Destination | Syfte |
|---|---|---|---|---|---|
| 100 | HTTP | TCP | 80 | `0.0.0.0/0` | Webbservern ansluter till externa tjänster via HTTP |
| 110 | HTTPS | TCP | 443 | `0.0.0.0/0` | Webbservern ansluter till externa tjänster via HTTPS |
| 120 | Custom TCP | TCP | 1024–65535 | `0.0.0.0/0` | Svar från webbservern till klienternas tillfälliga portar vid inkommande anslutningar |

### Syfte med Custom TCP (1024–65535)

Eftersom en NACL är **stateless** tillåts inte svarstrafik automatiskt. Både inkommande och utgående svar måste därför tillåtas med egna regler. Portintervallet 1024–65535 är de tillfälliga (ephemeral) portar som används för svarstrafik.

| Riktning | Scenario | Vad regeln tillåter |
|---|---|---|
| **Inbound 1024–65535** | Webbservern själv ansluter till en extern tjänst, till exempel för att hämta uppdateringar eller läsa från S3 | Svaret från den externa tjänsten når serverns tillfälliga port |
| **Outbound 1024–65535** | En klient ansluter in till webbservern på port 80, 443 eller 22 | Serverns svar når klientens tillfälliga port |

> [!NOTE]
> Svar på SSH-anslutningar (port 22) skickas också till klientens tillfälliga port och täcks därför av den utgående regeln 120.

### Verifiering

Inbound rules

<img width="1604" height="228" alt="inboundrules" src="https://github.com/user-attachments/assets/2b252bda-9597-45c7-87d0-b7cb5264a9e2" />

Outbound rules

<img width="1826" height="282" alt="outboundrules" src="https://github.com/user-attachments/assets/2094b3ff-97e7-4129-aab1-d6fd3ac64bcf" />

### SSH test

Lyckad inloggning 
<img width="920" height="72" alt="inloggssh" src="https://github.com/user-attachments/assets/f377bd18-2ebe-4f7d-8597-143bd6b4ed66" />

Nekad åtkomst via mobilnät
<img width="1322" height="110" alt="sshmobilnät" src="https://github.com/user-attachments/assets/31e56aab-046b-4ae2-870f-e2ddadc84f10" />

### Subnet association

NACL:en kopplades till `novatrix-public` så att reglerna gäller för det publika subnätet.

<img width="2054" height="236" alt="image" src="https://github.com/user-attachments/assets/3acfc9aa-5f2d-420b-b502-91f49a148a67" />

---

