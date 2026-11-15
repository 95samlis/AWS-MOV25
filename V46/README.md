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

## Steg 2. Data – Databas och lagring

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
