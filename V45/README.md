## V45 – Storage och databas

**SAMUEL LISSBRO**

### Syfte 

Syftet är att bygga en fungerande och säker WordPress-lösning genom att koppla ihop webbservern med databas och lagring, där databasen skyddas från offentlig åtkomst.

---

## Databas

RDS Subnet Group – `novatrix-db-subnets`

En DB subnet group talar om för RDS vilka subnät databasen får placeras i. Den skapades i förväg för att databasen ska hamna i de privata subnäten och inte vara nåbar direkt från internet.

## RDS – DB Subnet Group `novatrix-db-subnets`

I RDS-menyn valdes **Subnet groups** och en ny grupp skapades med namnet `novatrix-db-subnets`. Gruppen kopplades till VPC:et `novatrix-vpc` med Availability Zones `eu-north-1a` och `eu-north-1b`.

De privata subnäten `novatrix-private-a` och `novatrix-private-b`, som skapades tidigare, valdes till gruppen.

| Inställning | Värde |
|---|---|
| Namn | `novatrix-db-subnets` |
| VPC | `novatrix-vpc` |
| Availability Zones | `eu-north-1a`, `eu-north-1b` |
| Subnät | `novatrix-private-a`, `novatrix-private-b` |

Efter att gruppen skapats kontrollerades att båda subnäten fanns med.

**Syfte:** Förbereda de privata subnäten där RDS-databasen ska placeras.

### Verifiering

<img width="2340" height="88" alt="Skärmbild 2026-11-04 164855" src="https://github.com/user-attachments/assets/9bdfd117-2d87-4c64-be35-52297c946443" />

---

## Security Group för databasen

Jag skapar en EC2 Security Group innan jag skapar databasen, så att jag kan välja den direkt i RDS-formuläret senare.

Går till EC2 → Security Groups → Create security group.

- Name: `novatrix-db-sg`
- VPC: `novatrix-vpc`

Under Inbound rules lägger jag till:

- Type: MySQL/Aurora (port 3306)
- Source: Custom – väljer `novatrix-web-sg` i listan.

### Verifiering

<img width="2234" height="126" alt="Skärmbild 2026-11-04 170636" src="https://github.com/user-attachments/assets/9bb3cd23-c745-4cb7-a5f9-0c9515af1e4c" />

---


## RDS – Skapa databasen

Jag väljer Create database och anger följande inställningar:

- Engine: MariaDB 11.4.7
- DB instance identifier: `novatrix-db`

Under Connectivity väljer jag:

- VPC: `novatrix-vpc`
- DB subnet group: `novatrix-db-subnets`
- Public access: No
- VPC security group: `novatrix-db-sg`

Under Additional configuration:

- Port: 3306
- Initial database name: `Wordpress`
- Automated backups: Enabled
- Backup retention period: 1 day

### Lagringstid för backup i drift

I uppgiften använder jag 1 dags lagringstid på grund av Free Tier-begränsningen. I en riktig driftmiljö skulle jag välja 30 dagar. Det ger mer tid att upptäcka problem, till exempel om data raderas av misstag eller om databasen skadas. Med längre lagringstid finns fler möjligheter att återställa databasen till en tidigare tidpunkt. Det ger bättre skydd för verksamhetens data, även om kostnaden blir något högre.

### Verifiering

<img width="2284" height="164" alt="Skärmbild 2026-11-04 173757" src="https://github.com/user-attachments/assets/23f644f5-abed-488c-953a-a8c1fe95c55f" />

Här syns att databasen ligger i rätt VPC och privata subnet group, använder rätt Security Group och inte är publikt åtkomlig. Endpoint och port 3306 visas också.

<img width="600" height="150" alt="Skärmbild 2026-11-04 191253" src="https://github.com/user-attachments/assets/4db1b08d-6850-46dc-baae-0d6d63b46894" />


Kontroll av backup

<img width="600" height="200" alt="image" src="https://github.com/user-attachments/assets/35b79ade-794f-4d73-aeba-b55325277a9f" />


---

## NACL – Uppdatera utgående regler för databas och EFS

I `novatrix-public-nacl` under Outbound rules lägger jag till två nya regler:

- Regel 140: TCP, port 3306, destination `10.0.0.0/16` (databasen).
- Regel 150: TCP, port 2049, destination `10.0.0.0/16` (EFS).

**Syfte:** Tillåta webbservern att kommunicera med databasen och EFS. Utan reglerna riskerar anslutningarna att få timeout även om Security Groups är korrekt konfigurerade.

### Verifiering 

<img width="2348" height="122" alt="Skärmbild 2026-11-04 184358" src="https://github.com/user-attachments/assets/f1772507-beae-44ae-a05e-fac9750a6419" />

---

## DNS Hostnames och Security Group för EFS

Jag aktiverar DNS Hostnames i min VPC novatrix-vpc för att möjliggöra DNS-namn för resurser i nätverket.

- Name: `novatrix-efs-sg`
- VPC: `novatrix-vpc`
- Inbound rule: NFS (port 2049)
- Source: `novatrix-web-sg`

**Syfte:** Säkerhetsgruppen styr vilka som får ansluta till EFS. Genom att endast tillåta webbservern via port 2049 skyddas filsystemet från obehörig åtkomst.

### Verifiering

<img width="2298" height="120" alt="image" src="https://github.com/user-attachments/assets/e641ae4b-9be6-4556-9618-56bbd17ed57b" />

---


## Skapa EFS – Elastic File System

Jag skapar ett nytt EFS-filsystem med följande inställningar:

- Name: `novatrix-efs`
- VPC: `novatrix-vpc`

Jag skapar två Mount Targets i de privata subnäten:

- `novatrix-private-a`
- `novatrix-private-b`

Båda Mount Targets använder Security Group `novatrix-efs-sg`.

**Syfte:** Skapa en gemensam fillagring för WordPress som kan nås från webbservern via båda privata subnäten.

### Verifiering

<img width="1926" height="132" alt="Skärmbild 2026-11-04 220132" src="https://github.com/user-attachments/assets/877cbd2f-3e84-4578-aeb2-8e03a8b1bf64" />


Bilden visar i CloudTrail att två Mount Targets skapades.
<img width="2698" height="348" alt="image" src="https://github.com/user-attachments/assets/5aa510e2-ca67-464b-b023-6c21696240bd" />



---

## Montera EFS på webbservern

Jag SSH:ar in på `novatrix-web` och installerar `amazon-efs-utils`. Därefter skapar jag mappen `/var/www/html/wp-content` och monterar mitt EFS-filsystem med mitt filsystems-ID.

För att EFS ska monteras automatiskt vid omstart lägger jag till en rad i `/etc/fstab` med rätt EFS-ID och monteringssökväg.

Jag testar sedan monteringen genom att köra `sudo umount`, följt av `sudo mount -a` och kontrollerar resultatet med `df -h`.

### Verifiering

EFS är monterat och visas som ett tillgängligt filsystem på `/var/www/html/wp-content`.
<img width="1080" height="98" alt="Skärmbild 2026-11-04 230234" src="https://github.com/user-attachments/assets/76b1cc12-d671-43f7-be83-9e8da9608abc" />

---

## S3 – Bucket för backup

Jag skapar en S3-bucket i region Stockholm (`eu-north-1`) med namnet `novatrix-backup-95samlis-01`. All publik åtkomst blockeras och övriga inställningar lämnas som standard.

I bucketen skapar jag även mappen `backup`, där databasens säkerhetskopior ska lagras.

### Verifiering

<img width="1332" height="148" alt="image" src="https://github.com/user-attachments/assets/c8d3d108-3c98-4d8c-a833-c3600aa6f11e" />

public access är blockerat 

<img width="840" height="138" alt="image" src="https://github.com/user-attachments/assets/d95eeee6-43de-4a45-a93a-6162a3747b01" />


---

## S3 – Lifecycle rule

Jag skapar en livscykelregel med följande inställningar:

| Inställning | Värde |
|---|---|
| Rule name | `backup-14-days` |
| Prefix | `backup/` |
| Action | Expire current versions |
| Expiration | 14 dagar |

Regeln ser till att gamla databasbackuper raderas automatiskt efter 14 dagar.

### Verifiering

<img width="1804" height="128" alt="Skärmbild 2026-11-04 234435" src="https://github.com/user-attachments/assets/1047ad97-effb-491a-9fb1-4dd3e62b5fa7" />


<img width="270" height="272" alt="image" src="https://github.com/user-attachments/assets/1dbe2940-ad5a-4d2b-98a1-6ac356f7d56b" />

## Verifikation av lagringen 

Jag skapar testfilen `efs-test.txt` i `/var/www/html/wp-content/`, kontrollerar att den har skapats med `ls -l` och tar sedan bort den med `sudo rm`.

```bash
sudo touch /var/www/html/wp-content/efs-test.txt
ls -l /var/www/html/wp-content/efs-test.txt
sudo rm /var/www/html/wp-content/efs-test.txt
```

### Resultat

<img width="1212" height="80" alt="image" src="https://github.com/user-attachments/assets/6f45420f-7c8f-4c3a-8241-dd59d3fca395" />

---

## Installation av WordPress

Först installerade jag Apache, PHP och de PHP-tillägg som behövs för WordPress. Jag installerade även MariaDB-klienten för anslutningen till RDS-databasen.

```bash
sudo dnf install -y httpd wget php php-fpm php-mysqlnd php-mysqli php-gd php-mbstring php-xml mariadb105
```

Därefter laddade jag ner WordPress och packade upp installationsfilerna.

```bash
cd /tmp
wget https://wordpress.org/latest.tar.gz
tar -xzf latest.tar.gz
```

Jag kopierade WordPress-filerna till webbserverns dokumentmapp.

```bash
sudo cp -r /tmp/wordpress/* /var/www/html/
```

Den tidigare startsidan från uppgift V42 sparades i V45-projektet under namnet `index-v42.html`.

### Filbehörigheter

Jag ändrade ägarskapet på WordPress-filerna så att Apache kan hantera dem.

```bash
sudo chown -R apache:apache /var/www/html/
```

### Start av tjänster

Jag startade PHP-FPM och Apache.

```bash
sudo systemctl start php-fpm
sudo systemctl start httpd
```

### Verifiering

#### 1. Kontroll av Apache

```bash
sudo systemctl status httpd
```

Jag kontrollerade att Apache-webbservern körs. Resultatet visade `active (running)`.

<img width="1544" height="372" alt="Skärmbild 2026-11-05 154706" src="https://github.com/user-attachments/assets/4ca98f81-5d3f-43be-b125-b0ba2a9d4f9f" />


#### 2. Kontroll av PHP-FPM

```bash
sudo systemctl status php-fpm
```

Jag kontrollerade att PHP-FPM körs. Resultatet visade `active (running)`.

<img width="1358" height="198" alt="Skärmbild 2026-11-05 154752" src="https://github.com/user-attachments/assets/5112b54b-9f14-44bd-90c0-a498dc424e88" />



#### 3. Aktivera automatisk start

Jag aktiverade automatisk start för Apache och kontrollerade att båda tjänsterna är aktiverade.

```bash
sudo systemctl enable httpd
sudo systemctl is-enabled httpd php-fpm
```

Båda tjänsterna visade `enabled`, vilket innebär att de startar automatiskt när servern startas om.

<img width="1080" height="136" alt="Skärmbild 2026-11-05 154910" src="https://github.com/user-attachments/assets/fbb38eea-0181-488c-b665-41c95e4ccd55" />

---

## Anpassning av Apache för WordPress

När jag först testade webbservern visades inte WordPress startsida korrekt. Problemet var att Apache var inställd på att prioritera `index.html` framför `index.php`.

WordPress använder `index.php` som startsida. Jag ändrade därför inställningen i `/etc/httpd/conf/httpd.conf` från:

```apache
DirectoryIndex index.html
```

till:

```apache
DirectoryIndex index.php index.html
```

Därefter kontrollerade jag konfigurationen:

```bash
sudo httpd -t
```

Resultatet blev `Syntax OK`. Jag startade sedan om Apache för att ändringen skulle börja gälla:

```bash
sudo systemctl restart httpd
```

Efter ändringen fungerade WordPress startsida som förväntat.

**Att tänka på:** Kontrollera att `index.php` står före `index.html` i `DirectoryIndex`. Annars kan Apache visa en annan startsida än WordPress.

---

## Anslutning till RDS

Jag konfigurerade WordPress att ansluta till databasen i AWS RDS. Jag angav databasens namn, användaruppgifter och RDS-instansens endpoint.

När anslutningen var klar kunde WordPress använda RDS för att lagra webbplatsens data.

### Resultat

<img width="616" height="916" alt="testsida resulat3" src="https://github.com/user-attachments/assets/79a08f02-02c8-49dd-a51a-9625b3931ef3" />

## Verifiering av WordPress mot EFS

För att verifiera att WordPress använder EFS laddade jag upp en bild via WordPress Media Library.

Därefter kontrollerade jag via terminalen att bilden sparades i `/var/www/html/wp-content/uploads/`.

Eftersom `wp-content` är monterad mot EFS lagras WordPress uppladdade bilder på den delade lagringen.

### Verifiering

#### 1. WordPress Media Library

Visar den uppladdade bilden i WordPress.

<img width="644" height="358" alt="image" src="https://github.com/user-attachments/assets/5ac15c7c-a2c2-464c-84a2-d2eccf6ee2b3" />

#### 2. Terminal

Jag använde följande kommando för att kontrollera att bilden sparats i uppladdningsmappen:

```bash
sudo find /var/www/html/wp-content/uploads -type f
```

Resultatet visar den uppladdade bilden och dess automatiskt skapade bildvarianter.

<img width="1516" height="410" alt="Verifiering av WordPress-bilder på EFS" src="https://github.com/user-attachments/assets/6563c5c6-9a38-445f-a8f9-5d82da177193" />


---

## IAM-roll för uppladdning av backup till S3

Jag gick till IAM → Roles och öppnade rollen `novatrix-ec2-s3-read`. Rollen hade sedan tidigare endast läsbehörighet till S3.

Jag valde Add permissions och skapade en ny policy med JSON. Policyn ger rollen tillåtelse att ladda upp filer (`s3:PutObject`) till mappen `backup/` i min S3-bucket.

På så sätt kan EC2-servern både läsa från S3 och skriva backupfiler till den angivna mappen.

### Verifiering 

<img width="2176" height="106" alt="backup1" src="https://github.com/user-attachments/assets/f38a16e1-b38c-4731-b3a9-d90b04801690" />

<img width="1050" height="282" alt="backup 2" src="https://github.com/user-attachments/assets/e52a5245-b0a2-426d-8c3c-9243eb56bd49" />

---

## Backup av WordPress-databasen till S3

Jag skapade ett Bash-skript som säkerhetskopierar WordPress-databasen från RDS till en lokal SQL-fil på webbservern.

Därefter laddade jag upp backupfilen till mappen `backup/` i min S3-bucket. När uppladdningen var klar kontrollerade jag att filen fanns i S3.

Slutligen verifierade jag att den lokala backupfilen hade skapats och att filen fanns uppladdad i S3.

### Verifering

Lokal backupfil

<img width="1168" height="118" alt="backup reslutat" src="https://github.com/user-attachments/assets/a6586ab6-6854-46a4-97c4-fba52d10b72b" />

Backup uppladdad till S3

<img width="2578" height="134" alt="backup resultat2" src="https://github.com/user-attachments/assets/d9c30502-03fa-4ff4-85f4-6df825858408" />

---

## Arkitektur – sammanfattning

Min WordPress-webbplats använder fyra AWS-tjänster som arbetar tillsammans.

- **EC2** (`novatrix-web`): Här körs WordPress och webbservern.
- **RDS** (`novatrix-db`): Här sparas WordPress databas. Databasen ligger i privata subnät.
- **EFS** (`novatrix-efs`): Här sparas WordPress uppladdade bilder och filer. EFS är kopplat till webbservern.
- **S3** (`novatrix-backup-95samlis-01`): Här sparas databasbackuper. Backuper tas bort automatiskt efter 14 dagar.

Jag använder IAM för att ge EC2-servern tillåtelse att ladda upp backuper till S3.

Åtkomsten skyddas med Security Groups. Webbservern får ansluta till databasen och EFS, men databasen är inte öppen för allmänheten.

RDS har automatisk backup med 1 dags lagringstid.


