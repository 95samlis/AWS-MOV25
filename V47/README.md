v47 – Skalbarhet och tillgänglighet

**Samuel Lissbro**

### Syfte

Syftet är att göra Novatrix AB:s WordPress-lösning mer skalbar och tillgänglig i AWS. Med hjälp av Application Load Balancer och Auto Scaling ska lösningen kunna hantera varierande belastning och minska risken för driftavbrott genom att använda flera Availability Zones.

---

## Utökar nätverksstacken

Jag byggde ut den befintliga CloudFormation-stacken `novatrix-natverk` för att kunna köra miljön i två Availability Zones.

**Jag gjorde följande ändringar:**

- Lade till ett andra publikt subnät (`10.0.3.0/24`) i AZ B.
- Kopplade det till befintlig Route Table och Network ACL.
- Skapade en Security Group för ALB med HTTP och HTTPS.
- Ändrade webbserverns Security Group så att HTTP endast tillåts från ALB.
- Lade till Outputs för det nya subnätet och ALB:s Security Group.

**Genomförande:**

Jag validerade YAML-filen med AWS CLI, skapade ett Change Set och granskade ändringarna innan jag uppdaterade stacken i CloudFormation.

### Verifiering

Visar att ALB:s säkerhetsgrupp tillåter inkommande HTTP-trafik på port 80 och HTTPS-trafik på port 443.

<img width="1000" height="270" alt="albsg01" src="https://github.com/user-attachments/assets/607c3f3e-0393-4434-81c3-fdd66fc81005" />

Visar att det nya publika subnätet `novatrix-public-b` har CIDR `10.0.3.0/24` och ligger i Availability Zone `eu-north-1b`.

<img width="400" height="200" alt="subpublic02" src="https://github.com/user-attachments/assets/013bbc87-9a9c-4ae4-bd90-83e2c84ce87a" />

Visar det befintliga publika subnätet `novatrix-public` med CIDR `10.0.1.0/24` i Availability Zone `eu-north-1a`.

<img width="400" height="200" alt="subpublic01" src="https://github.com/user-attachments/assets/81c2f513-62f9-40d8-b8d2-89da0ec0efbf" />

Port 80 är stängd för direkt åtkomst, medan SSH fortfarande fungerar. Båda testerna gav förväntat resultat.

<img width="700" height="60" alt="sshlogin1" src="https://github.com/user-attachments/assets/2d030abe-a10a-4205-a846-d4b86ed0f353" />
<img width="350" height="180" alt="tcptest" src="https://github.com/user-attachments/assets/49e689f6-9cf5-4c25-a598-03781773b86f" />


---

## Skapa Launch Template för WordPress

Jag skapade en Launch Template för att kunna starta nya WordPress-instanser med samma inställningar.

**Inställningar:**

- Namn: `novatrix-web-lt`
- AMI: `novatrix-web-v47`
- Instanstyp: `t3.micro`
- Key pair: `nova-key`
- Security Group: `novatrix-web-sg`
- Auto Scaling guidance aktiverades.
- Ingen subnet valdes eftersom lastbalanseraren ska hantera placeringen av instanserna.
- Resource tag: `Name = novatrix-web` på instanserna.
- IAM-instansprofil: `novatrix-ec2-s3-read`
- Detailed CloudWatch monitoring aktiverades.

Launch Template skapades och kan nu användas som grund för att starta nya likadana WordPress-instanser.

### Resultat

<img width="1738" height="352" alt="template01" src="https://github.com/user-attachments/assets/f6ea6d60-4325-4f06-b88e-057a92998afd" />


---

## Förbereder Auto Scaling

Jag skapade en Target Group som ska användas för att koppla webbservrarna till lastbalanseraren.

**Inställningar:**

- Namn: `novatrix-web-tg`
- Target type: Instances
- Protokoll: HTTP
- Port: 80
- VPC: `novatrix-vpc`
- Health check path: `/wp-login.php`

Jag registrerade inga instanser ännu eftersom Target Group ska kopplas till lastbalanseraren senare.

### Resultat

<img width="1402" height="340" alt="image" src="https://github.com/user-attachments/assets/47127c2d-fd16-424c-80dd-40c9b6c12a87" />

### LASTBALANSERARE OCH LISTENER

Jag skapade en Load Balancer för att ta emot trafik och fördela den mellan webbservrarna.

**Inställningarna jag valde:**

- Namn: `novatrix-alb`
- Scheme: Internet-facing, så att användare kan nå webbplatsen via internet.
- IP address type: IPv4.
- VPC: `novatrix-vpc`, så att lastbalanseraren ligger i samma nätverk som webbservrarna.
- Availability Zones: Zon A och B med de publika subnäten. Det gör att lösningen kan fungera även om en zon får problem.
- Security Group: `novatrix-alb-sg`, som tillåter inkommande trafik på HTTP och HTTPS.
- Listener: HTTP på port 80.
- Routing: Trafiken skickas vidare till Target Group `novatrix-web-tg`.

På så sätt kan lastbalanseraren ta emot trafiken och skicka den vidare till rätt webbserver.

### Resultat

<img width="2306" height="310" alt="image" src="https://github.com/user-attachments/assets/0aa2f614-0dd3-4adc-99d8-2f50558ddcc6" />

---

## Uppdatera WordPress-adressen i databasen

Jag anslöt till RDS-databasen från webbservern via SSH och använde MariaDB för att ändra WordPress-adressen till min nya Application Load Balancer.

Jag uppdaterade värdena `siteurl` och `home` i tabellen `Wordpress.wp_options`.

Efteråt körde jag ett SELECT-kommando för att kontrollera ändringen. Båda värdena visade rätt DNS-adress till min Load Balancer.

Kommandot uppdaterade två rader utan några varningar.

### Resultat 

SELECT-kommandot bekräftar att både `home` och `siteurl` har uppdaterats till den nya ALB-adressen.

<img width="900" height="300" alt="Skärmbild 2026-11-24 055351" src="https://github.com/user-attachments/assets/dbe6f9cb-35d1-4e8b-8b6e-094e28d34891" />

---

## Auto Scaling Group

Jag skapade en Auto Scaling Group med namnet `novatrix-web-asg`, kopplad till `novatrix-web-lt` och `novatrix-web-tg`. Den gör att antalet webbservrar kan anpassas automatiskt efter belastningen och ökar tillgängligheten.

**Kapacitet och skalning:**

- Önskat antal instanser: 2
- Minsta antal instanser: 2
- Högsta antal instanser: 4
- Health checks via Elastic Load Balancing med 300 sekunders väntetid.
- Target tracking med Average CPU utilization på 50 %.

### Resultat

<img width="2708" height="248" alt="image" src="https://github.com/user-attachments/assets/6bec0c9d-da27-4ea3-aac2-6dc2bf9be61d" />



---

## Test – Borttagning av originalservern

### Syfte

Verifiera att WordPress fortsätter fungera via Application Load Balancer efter att den ursprungliga EC2-instansen tagits bort.

### Genomförande

1. Kontrollerade att Target Group `novatrix-web-tg` hade två friska instanser.
2. Kontrollerade att WordPress fungerade via ALB:s DNS-adress.
3. Uppdaterade CloudFormation-mallen `webb.yaml` för att ta bort originalresursen `NovatrixWeb`.
4. Validerade CloudFormation-mallen.
5. Skapade Change Set `remove-original-web-v2`.
6. Kontrollerade att Change Set visade:
   - Remove: `NovatrixWeb`
   - Add: `RetainPlaceholder`
7. Genomförde ändringen med `execute-change-set`.

### Verifiering

Originalinstansen visades som `Terminated`.

<img width="1958" height="158" alt="test02" src="https://github.com/user-attachments/assets/c9c07579-aeb7-43b6-9b4d-a60b7a12f1a4" />


Auto Scaling Group visade två instanser med status `InService` och `Healthy`.

<img width="2264" height="242" alt="test03" src="https://github.com/user-attachments/assets/cfd033a0-aed2-48f0-ab1d-c7ae5e878619" />


WordPress Admin kunde öppnas via ALB:s DNS-adress.
  
<img width="1650" height="440" alt="test04" src="https://github.com/user-attachments/assets/7c4f51cf-a119-4648-ab7f-a0facbb111d6" />

### Resultat

Testet visar att WordPress kan nås via Application Load Balancer och att Auto Scaling Group har två friska instanser efter borttagningstestet.

---






