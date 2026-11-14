## V46 – IaC med CloudFormation

**SAMUEL LISSBRO**

Mitt Repo: https://github.com/95samlis/AWS-MOV25/tree/main

### Syfte 

Syftet med uppgiften är att använda Infrastructure as Code (IaC) med AWS CloudFormation för att automatisera skapandet av Novatrix AB:s infrastruktur. Genom att skriva templates och versionshantera dem i GitHub ska miljön kunna återskapas på ett enkelt, effektivt och reproducerbart sätt.

---

### Steg 1 – Nätverk med CloudFormation

Jag började migreringen till Infrastructure as Code genom att skapa en CloudFormation-template för Novatrix AB nätverksinfrastruktur.

Templaten innehåller:

En VPC med CIDR 10.0.0.0/16.

Ett publikt subnet.

Två privata subnet i separata Availability Zones.

En Internet Gateway kopplad till VPC.

Syftet är att kunna skapa nätverksinfrastrukturen reproducerbart genom CloudFormation i stället för att konfigurera resurserna manuellt i AWS-konsolen.
