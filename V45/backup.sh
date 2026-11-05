
#!/bin/bash
# Backup av WordPress-databasen till S3

# 1. Skapa backup av databasen
mysqldump --single-transaction -h novatrix-db.cxmeyaio0zvp.eu-north-1.rds.amazonaws.com -u admin -p Wordpress > wordpress-$(date +%F).sql

# 2. Kopiera backupen till S3
aws s3 cp wordpress-$(date +%F).sql s3://novatrix-backup-95samlis-01/backup/

# 3. Kontrollera att backupen finns i S3
aws s3 ls s3://novatrix-backup-95samlis-01/backup/

# 4. Ta bort den lokala kopian
rm wordpress-$(date +%F).sql