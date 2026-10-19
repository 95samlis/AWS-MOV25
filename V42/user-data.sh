#!/bin/bash
set -Eeuo pipefail

# Logga allt till en fil för felsökning
exec > /var/log/user-data-novatrix.log 2>&1
trap 'echo "USER_DATA_FAILED på rad $LINENO"' ERR

echo "Startar installation av Novatrix-webbservern"

# Installera Apache
dnf install -y httpd

# Hämta Novatrix-sidan från GitHub
curl --fail --location --retry 5 --retry-delay 3 \
  https://raw.githubusercontent.com/95samlis/AWS-MOV25/main/V42/index.html \
  --output /var/www/html/index.html

# Kontrollera att HTML-filen inte är tom
test -s /var/www/html/index.html

# Sätt rätt filbehörigheter
chmod 644 /var/www/html/index.html

# Starta Apache och aktivera tjänsten vid uppstart
systemctl enable --now httpd

# Kontrollera att Apache svarar lokalt
curl --fail http://localhost/ >/dev/null

echo "USER_DATA_DONE"
echo "Novatrix-webbservern är klar"