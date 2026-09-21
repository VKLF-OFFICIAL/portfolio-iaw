#!/usr/bin/env bash
# Instala Apache + PHP y publica el sitio ejemplo.local
set -euo pipefail

sudo apt update
sudo apt install -y apache2 php libapache2-mod-php

sudo mkdir -p /var/www/ejemplo
sudo cp index.php /var/www/ejemplo/
sudo cp vhost.conf /etc/apache2/sites-available/ejemplo.conf

sudo a2ensite ejemplo.conf
sudo a2dissite 000-default.conf
sudo systemctl reload apache2

echo "127.0.0.1 ejemplo.local" | sudo tee -a /etc/hosts
curl -s http://ejemplo.local/
