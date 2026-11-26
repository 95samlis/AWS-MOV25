V48 - Monitorering och cloud native

**Samuel Lissbro**

### Syfte 

Syftet med uppgiften är att lära mig övervaka en AWS-miljö med hjälp av CloudWatch. Jag ska hålla koll på CPU, minne, disk och loggar för att upptäcka problem i tid. Jag ska även undersöka hur man kan använda containers eller serverless för att göra lösningen mer flexibel och skalbar.

---

## 1. Samla mätvärden och skapa Dashboard i CloudWatch

Jag började med att samla viktiga mätvärden från EC2 och lastbalanseraren (ALB) i CloudWatch för att få en bättre överblick över hur min AWS-lösning fungerar.

**Jag valde följande mätvärden:**

- CPUUtilization (Average): Genomsnittlig CPU-användning.
- RequestCount (Sum): Totalt antal förfrågningar.
- TargetResponseTime (Average): Genomsnittlig svarstid.
- HealthyHostCount (Maximum): Högsta antalet fungerande servrar.
- UnHealthyHostCount (Maximum): Högsta antalet servrar som inte fungerar.

Jag valde en period på 5 minuter för alla mätvärden.

För att samla allt på ett ställe skapade jag en CloudWatch Dashboard med namnet `novatrix-dashboard`. Där kan jag enkelt följa mätvärdena och få en överblick över hur lösningen mår.

### Resultat

