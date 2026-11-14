## V46 – IaC med CloudFormation

**SAMUEL LISSBRO**

Mitt Repo: https://github.com/95samlis/AWS-MOV25/tree/main

### Syfte 

Syftet med uppgiften är att använda Infrastructure as Code (IaC) med AWS CloudFormation för att automatisera skapandet av Novatrix AB:s infrastruktur. Genom att skriva templates och versionshantera dem i GitHub ska miljön kunna återskapas på ett enkelt, effektivt och reproducerbart sätt.

---

## Steg 1 – Nätverk med CloudFormation

Jag skapade en CloudFormation-template (`network.yaml`) för att automatisera skapandet av nätverket i AWS.

### Templaten innehåller

- En **VPC** med CIDR `10.0.0.0/16`.
- Ett **publikt subnät** (`10.0.1.0/24`).
- Två **privata subnät** (`10.0.2.0/24` och `10.0.4.0/24`) i olika Availability Zones.
- En **Internet Gateway** kopplad till VPC.
- En **Route Table** som ger det publika subnätet tillgång till internet.
- **Outputs** som gör att andra CloudFormation-stackar kan använda VPC:ns och subnätens ID.

### Validering av template

Jag laddade upp `network.yaml` till AWS CloudShell och körde kommandot:

```bash
aws cloudformation validate-template --template-body file://network.yaml
```

AWS kunde läsa templaten utan att visa några fel.

### Skapa CloudFormation-stack

Efter valideringen skapade jag en CloudFormation-stack med namnet `novatrix-natverk`:

```bash
aws cloudformation create-stack \
  --stack-name novatrix-natverk \
  --template-body file://network.yaml
```

Jag kontrollerade sedan stackens status med:

```bash
aws cloudformation describe-stacks \
  --stack-name novatrix-natverk \
  --query "Stacks[0].StackStatus"
```

### Resultat

<img width="718" height="168" alt="Skärmbild 2026-11-14 211729" src="https://github.com/user-attachments/assets/9cec4c97-6f67-4631-9894-4cb361626ff1" />

<img width="2010" height="150" alt="image" src="https://github.com/user-attachments/assets/64a363a6-804a-4c21-b406-a78981755480" />

## Deployment och verifiering

Jag skapade stacken `novatrix-natverk` via AWS CloudFormation. Stacken fick statusen `CREATE_COMPLETE` och samtliga 9 resurser skapades utan fel.

### Resultat

<img width="1530" height="1100" alt="Skärmbild 2026-11-14 212228" src="https://github.com/user-attachments/assets/c0fc682e-a5ee-49a2-bdb6-8c697399c206" />
