## V46 – IaC med CloudFormation

**SAMUEL LISSBRO**

Mitt Repo: https://github.com/95samlis/AWS-MOV25/tree/main

### Syfte 

Syftet med uppgiften är att använda Infrastructure as Code med AWS CloudFormation för att automatisera skapandet av Novatrix AB:s infrastruktur. Genom att skriva templates och versionshantera dem i GitHub ska miljön kunna återskapas på ett enkelt, effektivt och reproducerbart sätt.

---

## Steg 1 – Nätverk med CloudFormation

Jag skapade en CloudFormation-template (`network.yaml`) för att automatisera skapandet av nätverksinfrastrukturen i AWS.

### Templaten innehåller

- En **VPC** med CIDR `10.0.0.0/16`.
- Ett **publikt subnät** (`10.0.1.0/24`).
- Två **privata subnät** (`10.0.2.0/24` och `10.0.4.0/24`) i olika Availability Zones.
- En **Internet Gateway** kopplad till VPC.
- En **publik Route Table** med internetroute.
- En **privat Route Table** med lokal trafik inom VPC.
- En **Security Group** för webbservern med regler för HTTP, HTTPS och SSH.
- En **Network ACL** för det publika subnätet med inkommande och utgående regler.
- **Outputs** som gör att andra CloudFormation-stackar kan använda ID för VPC, subnät och webbserverns Security Group.

### Validering av template

Jag laddade upp `network.yaml` till AWS CloudShell och körde kommandot:

```bash
aws cloudformation validate-template --template-body file://network.yaml
```

AWS kunde läsa templaten utan att visa några fel.

### Skapa och uppdatera CloudFormation-stack

Jag skapade först en CloudFormation-stack med namnet `novatrix-natverk`. Den första versionen skapade nätverkets grundläggande resurser.

Därefter kompletterade jag `network.yaml` med Security Group, Network ACL och den privata route tabellen.

Jag validerade den uppdaterade templaten och skapade ett Change Set med namnet `novatrix-natverk-update`. Efter granskning körde jag ändringarna på den befintliga stacken.

### Verifikation

Den uppdaterade stacken fick statusen `UPDATE_COMPLETE`. Samtliga 27 resurser visas med statusen `CREATE_COMPLETE` i CloudFormation.

### Resultat

<img width="2018" height="480" alt="image" src="https://github.com/user-attachments/assets/d640393c-bcd5-440b-8d3c-bd7e2a0c481c" />

---

## Steg 2 - Data – Databas och lagring

I detta steg skapade jag en databas och en lagringsyta med CloudFormation. Jag använde filen `data.yaml`.

### Databas (RDS)

Jag skapade en MariaDB-databas som återställdes från min tidigare backup från V45.

- Databasens namn: `novatrix-db`
- Databasmotor: MariaDB 11.4.7
- Lagring: 20 GiB
- Port: 3306
- Publik åtkomst: Nej

På detta sätt kunde jag behålla informationen från min tidigare WordPress-databas.

### Säkerhetsgrupp för databasen

Jag skapade säkerhetsgruppen `novatrix-db-sg`. Den tillåter anslutning på port 3306 från webbserverns säkerhetsgrupp.

### EFS – gemensam lagring

Jag skapade ett EFS-filsystem med namnet `novatrix-efs`.

Jag skapade två mount targets:

- Ett i Private Subnet A.
- Ett i Private Subnet B.

Jag skapade också säkerhetsgruppen `novatrix-efs-sg`. Den tillåter trafik på port 2049 från webbserverns säkerhetsgrupp.

### Kontroll av resultatet

Efter driftsättningen kontrollerade jag CloudFormation. Alla sju resurser fick statusen `CREATE_COMPLETE`.

Jag kontrollerade också att databasen och EFS hade skapats och att CloudFormation visade rätt anslutningsuppgifter.

### Verifiering

<img width="1344" height="474" alt="image" src="https://github.com/user-attachments/assets/49c50d83-a9f1-4712-97d7-bb2a84cf83f9" />


### Problem och lösning

Vid första försöket misslyckades skapandet av Data-stacken. En gammal DB Subnet Group med samma namn fanns redan i AWS och tillhörde den gamla VPC.

Jag kontrollerade den gamla gruppen och såg att den inte längre behövdes. Jag tog bort den och försökte skapa Data-stacken igen.

Det andra försöket lyckades.

---

## steg 3 - Webbserver

### Återskapa webbservern från backup

Jag använde min tidigare AMI-backup från V45 för att återskapa webbservern.

- AMI: `novatrix-web-v45-backup`
- AMI-ID: `ami-06d456b5d1e648906`

Jag skapade en ny EC2-instans med CloudFormation och filen `webb.yaml`.

### Inställningar

| Inställning | Värde |
|---|---|
| Instansnamn | `novatrix-web` |
| Instanstyp | `t3.micro` |
| AMI | `novatrix-web-v45-backup` |
| Nyckelpar | `nova-key` |
| VPC | `novatrix-vpc` (den nya V46-VPC:n) |
| Subnät | Public Subnet |
| Säkerhetsgrupp | `novatrix-web-sg` |

### Verifiering

<img width="1916" height="122" alt="image" src="https://github.com/user-attachments/assets/81f9c8c7-97b1-45db-8998-4ad4127bbdf6" />

---
## Kontroll av webbservern

När webbservern var skapad anslöt jag till den via SSH.
Jag kontrollerade att Apache och PHP-FPM var igång:

```bash
sudo systemctl status httpd
sudo systemctl status php-fpm
```

Båda tjänsterna visade `active (running)`.
Jag kontrollerade också att WordPress-filerna fanns i `/var/www/html/`.

### Kontroll av databasanslutningen

Jag testade att webbservern kunde ansluta till databasen i RDS.

```bash
mysql -h novatrix-db.cxmeyaio0zvp.eu-north-1.rds.amazonaws.com -u admin -p -D Wordpress -e "SELECT 1;"
```

Testet lyckades och visade resultatet `1`.

### Montera EFS

Efter att webbservern skapats upptäckte jag att EFS inte var monterat.
Jag monterade därför EFS på WordPress-mappen `wp-content`.

```bash
sudo mount -t efs -o tls fs-054c6d4ac5a6b8771:/ /var/www/html/wp-content
```

Jag kontrollerade att monteringen fungerade med:

```bash
df -h
```

EFS visades på rätt plats.

### Skapa mappar och installera temat

När EFS var monterat upptäckte jag att det var tomt. Jag skapade därför mapparna för teman, tillägg och bilder.

```bash
sudo mkdir -p /var/www/html/wp-content/{themes,plugins,uploads}
```

Databasen visade att WordPress använde temat Twenty Twenty-Five. Jag laddade ner temat:

```bash
cd /tmp
wget https://downloads.wordpress.org/theme/twentytwentyfive.zip
```

Sedan packade jag upp temat i EFS:

```bash
sudo unzip /tmp/twentytwentyfive.zip -d /var/www/html/wp-content/themes/
```

Jag ändrade även ägarskapet så att Apache kunde använda filerna:

```bash
sudo chown -R apache:apache /var/www/html/wp-content/
```

### Ändra WordPress-adressen

Efter återställningen använde WordPress fortfarande den gamla webbserverns IP-adress.
Jag ändrade därför adressen till den nya webbserverns publika IP-adress `16.171.58.15`.

```bash
sudo -u apache php -r 'require "/var/www/html/wp-load.php"; update_option("siteurl","http://16.171.58.15"); update_option("home","http://16.171.58.15");'
```

### Resultat

WordPress fungerade nu med den nya webbservern, den återställda databasen och EFS.
Jag kunde logga in på WordPress och komma åt administrationspanelen.

<img width="1632" height="576" alt="image" src="https://github.com/user-attachments/assets/45bd1d5b-8e34-4acf-8bd0-63ec0340527b" />


### Verifiering

Bilden visar att båda tidigare WordPress-inläggen finns kvar efter återställningen.

<img width="2886" height="368" alt="image" src="https://github.com/user-attachments/assets/af6db0df-1978-4d17-831a-2b2014377d71" />

---

## Versionshantering

Jag har sparat mina tre YAML-filer i GitHub och gjort commits när jag har ändrat något. I historiken kan man se vad som har lagts till och ändrats.

Versionshantering gör det enklare att hitta fel och gå tillbaka till en tidigare version om något inte fungerar. Det gör också att andra kan se hur arbetet är uppbyggt och fortsätta utveckla det som redan har gjorts.

Det blir även lättare att samarbeta eftersom alla kan utgå från samma version av filerna.

---

## Återskapa stacken

För att återskapa infrastrukturen hämtar man CloudFormation-filerna från mitt GitHub-repo. Sedan skapar man stackarna i AWS i rätt ordning:

1. `network.yaml` – skapar VPC, subnät och säkerhetsgrupper.
2. `data.yaml` – skapar RDS-databasen och EFS-lagringen.
3. `webb.yaml` – skapar EC2-instansen som kör WordPress.

Filerna hänger ihop och använder värden från varandra. Därför måste nätverket skapas först, sedan databasen och lagringen och sist webbservern.

Jag valde att använda min befintliga AMI och databassnapshot från V45. Det var en genväg för att slippa installera och konfigurera Apache, PHP och WordPress en gång till. På så sätt kunde jag lägga mer tid på att bygga infrastrukturen med CloudFormation.

För att kunna återskapa allt behöver AMI, databassnapshoten och nyckelparet `nova-key` också finnas tillgängliga i AWS.

