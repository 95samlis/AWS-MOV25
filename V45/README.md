## V45 – Storage och databas

**SAMUEL LISSBRO**

### Syfte 

Syftet är att bygga en fungerande och säker WordPress-lösning genom att koppla ihop webbservern med databas och lagring, där databasen skyddas från offentlig åtkomst.

---

## Databas

RDS Subnet Group – `novatrix-db-subnets`

En DB subnet group talar om för RDS vilka subnät databasen får placeras i. Den skapades i förväg för att databasen ska hamna i de privata subnäten och inte vara nåbar direkt från internet.

## 1. RDS – DB Subnet Group `novatrix-db-subnets`

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


