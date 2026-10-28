```bash
#!/bin/bash
set -e

# Novatrix - IAM users and groups

# 1. Skapa IAM-grupper om de saknas
if ! aws iam get-group --group-name Utveckling >/dev/null 2>&1; then
  aws iam create-group --group-name Utveckling
fi

if ! aws iam get-group --group-name Drift >/dev/null 2>&1; then
  aws iam create-group --group-name Drift
fi

# 2. Skapa IAM-användare om de saknas
if ! aws iam get-user --user-name dev-erik >/dev/null 2>&1; then
  aws iam create-user --user-name dev-erik
fi

if ! aws iam get-user --user-name drift-david >/dev/null 2>&1; then
  aws iam create-user --user-name drift-david
fi

# 3. Lägg användarna i rätt grupper
aws iam add-user-to-group \
  --user-name dev-erik \
  --group-name Utveckling

aws iam add-user-to-group \
  --user-name drift-david \
  --group-name Drift

echo "Novatrix IAM users and groups are configured."
echo "Console login profiles will be configured separately."
```
