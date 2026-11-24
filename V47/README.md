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

<img width="1000" height="300" alt="albsg01" src="https://github.com/user-attachments/assets/607c3f3e-0393-4434-81c3-fdd66fc81005" />

Visar att det nya publika subnätet `novatrix-public-b` har CIDR `10.0.3.0/24` och ligger i Availability Zone `eu-north-1b`.

<img width="400" height="200" alt="subpublic02" src="https://github.com/user-attachments/assets/013bbc87-9a9c-4ae4-bd90-83e2c84ce87a" />

Visar det befintliga publika subnätet `novatrix-public` med CIDR `10.0.1.0/24` i Availability Zone `eu-north-1a`.

<img width="400" height="200" alt="subpublic01" src="https://github.com/user-attachments/assets/81c2f513-62f9-40d8-b8d2-89da0ec0efbf" />

Port 80 är stängd för direkt åtkomst, medan SSH fortfarande fungerar. Båda testerna gav förväntat resultat.

<img width="700" height="60" alt="sshlogin1" src="https://github.com/user-attachments/assets/2d030abe-a10a-4205-a846-d4b86ed0f353" />
<img width="350" height="180" alt="tcptest" src="https://github.com/user-attachments/assets/49e689f6-9cf5-4c25-a598-03781773b86f" />


---





