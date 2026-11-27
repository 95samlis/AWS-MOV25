V48 - Monitorering och cloud native

**Samuel Lissbro**

### Syfte 

Syftet med uppgiften är att lära mig övervaka en AWS-miljö med hjälp av CloudWatch. Jag ska hålla koll på CPU, minne, disk och loggar för att upptäcka problem i tid. Jag ska även undersöka hur man kan använda containers eller serverless för att göra lösningen mer flexibel och skalbar.

---

## 1. Samlar in mätvärden och skapar Dashboard i CloudWatch

Jag började med att samla viktiga mätvärden från EC2 och lastbalanseraren i CloudWatch för att få en bättre överblick över hur min AWS-lösning fungerar.

**Jag valde följande mätvärden:**

- CPUUtilization (Average): Genomsnittlig CPU-användning.
- RequestCount (Sum): Totalt antal förfrågningar.
- TargetResponseTime (Average): Genomsnittlig svarstid.
- HealthyHostCount (Maximum): Högsta antalet fungerande servrar.
- UnHealthyHostCount (Maximum): Högsta antalet servrar som inte fungerar.

Jag valde en period på 5 minuter för alla mätvärden.

För att samla allt på ett ställe skapade jag en CloudWatch Dashboard med namnet `novatrix-dashboard`. Där kan jag enkelt följa mätvärdena och få en överblick över hur lösningen mår.

### Resultat

<img width="1490" height="756" alt="Skärmbild 2026-11-26 065528" src="https://github.com/user-attachments/assets/34501170-cccd-4782-81bd-231f8d2977d7" />


## 2. IAM-behörigheter

Jag lade till behörigheter för CloudWatch Agent i `webb.yaml` och uppdaterade CloudFormation-stacken. Uppdateringen gick igenom utan fel.

## 3. Parameter Store

Jag skapade parametern `AmazonCloudWatch-novatrix` med konfigurationen för CloudWatch Agent. Jag testade med AWS CLI och kunde hämta konfigurationen.

### Resultat

<img width="2258" height="272" alt="Skärmbild 2026-11-26 094700" src="https://github.com/user-attachments/assets/ebcf2608-867f-4fea-8dc2-1c92294d1faa" />


## 4. Log Groups

Jag skapade två Log Groups i CloudWatch:

- `/novatrix/httpd/access`
- `/novatrix/httpd/error`

Båda sparar loggar i två veckor.

<img width="2788" height="318" alt="Skärmbild 2026-11-26 093957" src="https://github.com/user-attachments/assets/828dddde-c7c4-47d3-bf3e-5d2a92e41b76" />

### 5. Launch Template

Jag skapade version 2 av novatrix-web-lt och lade till User Data för installation och start av CloudWatch Agent. Jag kontrollerade även att version 2 var vald som standardversion.
<img width="2116" height="90" alt="image" src="https://github.com/user-attachments/assets/abb8d821-7e7e-43eb-93e1-739773a4c5fd" />


## 6. Instance refresh och verifiering

Jag startade en Instance Refresh på `novatrix-web-asg` för att byta ut servrarna så att de använder den nya versionen med CloudWatch Agent. Uppdateringen slutfördes utan problem och jag kontrollerade att statusen var Successful och att 100 % av instanserna hade uppdaterats.

### Resultat

<img width="2052" height="282" alt="Skärmbild 2026-11-26 114206" src="https://github.com/user-attachments/assets/50066c02-fc6f-4754-9bbd-362ab1ca6b49" />

## 7. Disk- och minnesmätvärden

Efter installationen av CloudWatch Agent kan jag även se disk- och minnesanvändningen i CloudWatch. Mätvärdena `disk_used_percent` och `mem_used_percent` visar hur stor andel av disk respektive minne som används i Auto Scaling-gruppen `novatrix-web-asg`.

### Resultat 

<img width="2812" height="822" alt="image" src="https://github.com/user-attachments/assets/d69d5074-d527-482b-8bb0-f467e4ef1be4" />


