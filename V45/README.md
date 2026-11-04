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

### Verifiering

<img width="2284" height="164" alt="Skärmbild 2026-11-04 173757" src="https://github.com/user-attachments/assets/23f644f5-abed-488c-953a-a8c1fe95c55f" />

Här syns att databasen ligger i rätt VPC och privata subnet group, använder rätt Security Group och inte är publikt åtkomlig. Endpoint och port 3306 visas också.

<img width="1200" height="330" alt="Skärmbild 2026-11-04 191253" src="https://github.com/user-attachments/assets/4db1b08d-6850-46dc-baae-0d6d63b46894" />


Kontroll av backup

<img width="1290" height="294" alt="image" src="https://github.com/user-attachments/assets/35b79ade-794f-4d73-aeba-b55325277a9f" />


---

## NACL – Uppdatera utgående regler för databas och EFS

I `novatrix-public-nacl` under Outbound rules lägger jag till två nya regler:

- Regel 140: TCP, port 3306, destination `10.0.0.0/16` (databasen).
- Regel 150: TCP, port 2049, destination `10.0.0.0/16` (EFS).

**Syfte:** Tillåta webbservern att kommunicera med databasen och EFS. Utan reglerna riskerar anslutningarna att få timeout även om Security Groups är korrekt konfigurerade.

### Verifiering 

<img width="2348" height="122" alt="Skärmbild 2026-11-04 184358" src="https://github.com/user-attachments/assets/f1772507-beae-44ae-a05e-fac9750a6419" />

---



