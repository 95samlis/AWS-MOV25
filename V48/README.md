# V48 - Monitorering och cloud native

**Samuel Lissbro**

### Syfte 

Syftet med uppgiften är att lära mig övervaka en AWS-miljö med hjälp av CloudWatch. Jag ska hålla koll på CPU, minne, disk och loggar för att upptäcka problem i tid. Jag ska även undersöka hur man kan använda containers eller serverless för att göra lösningen mer flexibel och skalbar.

---

### Genomförande 

I den här uppgiften har jag arbetat med att övervaka min AWS-lösning med hjälp av CloudWatch. Jag har satt upp insamling av mätvärden och loggar, skapat larm som skickar mejl via SNS och byggt en dashboard där jag kan se hur lösningen fungerar.

Här går jag igenom vad jag har gjort steg för steg och visar resultatet med skärmbilder.

## Innehållsförteckning

1. [IAM-behörigheter](#1-iam-behörigheter)
2. [Parameter Store](#2-parameter-store)
3. [Log Groups](#3-log-groups)
4. [Launch Template](#4-launch-template)
5. [Instance refresh och verifiering](#5-instance-refresh-och-verifiering)
6. [Disk- och minnesmätvärden](#6-disk--och-minnesmätvärden)
7. [SNS och larm i CloudWatch](#7-sns-och-larm-i-cloudwatch)
8. [Test av larmkedjan](#8-test-av-larmkedjan)
9. [Dashboard i CloudWatch – novatrix-drift](#9-dashboard-i-cloudwatch--novatrix-drift)

---

## 1. IAM-behörigheter

Jag lade till behörigheter för CloudWatch Agent i `webb.yaml` och uppdaterade CloudFormation-stacken. Uppdateringen gick igenom utan fel.

## 2. Parameter Store

Jag skapade parametern `AmazonCloudWatch-novatrix` med konfigurationen för CloudWatch Agent. Jag testade med AWS CLI och kunde hämta konfigurationen.

### Resultat

<img width="2258" height="272" alt="Skärmbild 2026-11-26 094700" src="https://github.com/user-attachments/assets/ebcf2608-867f-4fea-8dc2-1c92294d1faa" />


## 3. Log Groups

Jag skapade två Log Groups i CloudWatch:

- `/novatrix/httpd/access`
- `/novatrix/httpd/error`

Båda sparar loggar i två veckor.

<img width="2788" height="318" alt="Skärmbild 2026-11-26 093957" src="https://github.com/user-attachments/assets/828dddde-c7c4-47d3-bf3e-5d2a92e41b76" />

## 4. Launch Template

Jag skapade version 2 av novatrix-web-lt och lade till User Data för installation och start av CloudWatch Agent. Jag kontrollerade även att version 2 var vald som standardversion.
<img width="2116" height="90" alt="image" src="https://github.com/user-attachments/assets/abb8d821-7e7e-43eb-93e1-739773a4c5fd" />


## 5. Instance refresh och verifiering

Jag startade en Instance Refresh på `novatrix-web-asg` för att byta ut servrarna så att de använder den nya versionen med CloudWatch Agent. Uppdateringen slutfördes utan problem och jag kontrollerade att statusen var Successful och att 100 % av instanserna hade uppdaterats.

### Resultat

<img width="2052" height="282" alt="Skärmbild 2026-11-26 114206" src="https://github.com/user-attachments/assets/50066c02-fc6f-4754-9bbd-362ab1ca6b49" />

## 6. Disk- och minnesmätvärden

Efter installationen av CloudWatch Agent kan jag även se disk- och minnesanvändningen i CloudWatch. Mätvärdena `disk_used_percent` och `mem_used_percent` visar hur stor andel av disk respektive minne som används i Auto Scaling-gruppen `novatrix-web-asg`.

### Resultat 

<img width="2812" height="822" alt="image" src="https://github.com/user-attachments/assets/d69d5074-d527-482b-8bb0-f467e4ef1be4" />

### Log Analytics i CloudWatch

Jag konfigurerade en fråga som tar bort automatiska ELB HealthChecker-anrop från access-loggen och räknar antalet förfrågningar per HTTP-svar.

### Resultat


<img width="1636" height="508" alt="Skärmbild 2026-11-27 232533" src="https://github.com/user-attachments/assets/2aaeb645-8796-4332-a69d-153676e16937" />

### Sammanfattning

Nu har jag samlat mätvärden och loggar i CloudWatch. Det gör det enklare att följa hur servrarna mår och upptäcka problem. Nästa steg är att ställa in larm som meddelar mig när något inte fungerar som det ska.

---

## 7. SNS och larm i CloudWatch

Jag skapade ett SNS-topic med namnet `novatrix-larm`. Dit skickas alla larm som sedan skickas vidare till prenumeranterna.

Jag lade till min e-postadress som prenumerant och bekräftade den via mejlet från AWS.

### Larmkonfiguration

Jag skapade fyra larm i CloudWatch för att hålla koll på servrarna:

- CPU – `novatrix-cpu-high`: Larm när CPU-användningen överstiger 70 % under 5 minuter.
- Minne – `novatrix-memory-high`: Larm när minnesanvändningen överstiger 85 % under 5 minuter.
- Disk – `novatrix-disk-high`: Larm när diskanvändningen på `/` överstiger 85 % under 5 minuter.
- Unhealthy – `novatrix-unhealthy`: Larm när minst en server inte fungerar som den ska under 3 minuter. Jag övervakar `eu-north-1a`.

Alla larm skickar meddelanden via `novatrix-larm`. Jag får även ett mejl när ett larm går tillbaka till normalt läge.

### Resultat

<img width="2230" height="242" alt="image" src="https://github.com/user-attachments/assets/ef0a204c-924e-42f0-8a12-cd1df34ab400" />


## 8. Test av larmkedjan

Jag körde följande kommando i AWS CloudShell för att testa CPU-larmet:

```bash
aws cloudwatch set-alarm-state \
  --alarm-name novatrix-cpu-high \
  --state-value ALARM \
  --state-reason "Test av larmkedjan" \
  --region eu-north-1
```

Jag fick ett mejl när larmet gick till ALARM och ett nytt när det återgick till OK. Testet fungerade.

### Resultat 

<img width="800" height="70" alt="image" src="https://github.com/user-attachments/assets/b467b113-2c23-4ec2-a729-9ae335023e30" />


---

## 9. Dashboard i CloudWatch – `novatrix-drift`

Jag skapade en dashboard i CloudWatch med namnet `novatrix-drift` för att samla övervakningen på ett ställe.

Jag lade till följande delar:

1. Alarm status: Visar status för de fyra larmen: CPU, disk, minne och unhealthy hosts.
2. CPU: Ett linjediagram som visar CPU-användningen för Auto Scaling-gruppen med värdet Average.
3. Minne och disk: Ett linjediagram som visar minnes- och diskanvändningen för gruppen med värdet Maximum.
4. Healthy och UnHealthyHostCount: Ett linjediagram som visar antalet friska och icke friska servrar.
5. RequestCount: En siffervisning som visar antalet förfrågningar till lastbalanseraren.

Dashboarden samlar larmen och mätvärdena på ett ställe, vilket gör det enklare att följa lösningen. Se bilden nedan.

### Resultat

<img width="3182" height="856" alt="image" src="https://github.com/user-attachments/assets/f99fb0e7-e749-4579-8e33-6d3343324f85" />



---
