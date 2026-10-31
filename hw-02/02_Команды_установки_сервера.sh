#!/bin/bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y postgresql curl ca-certificates wget locales
sed -i 's/^# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
cd /tmp
wget -q https://repo.zabbix.com/zabbix/7.4/release/debian/pool/main/z/zabbix-release/zabbix-release_latest_7.4+debian12_all.deb
dpkg -i zabbix-release_latest_7.4+debian12_all.deb
apt-get update
apt-get install -y zabbix-server-pgsql zabbix-frontend-php php8.2-pgsql zabbix-apache-conf zabbix-sql-scripts zabbix-agent zabbix-get
systemctl enable --now postgresql
DB_PASSWORD=$(openssl rand -hex 18)
printf '%s\n' "$DB_PASSWORD" > /root/zabbix-db-password
chmod 600 /root/zabbix-db-password
sudo -u postgres psql -v ON_ERROR_STOP=1 -c "CREATE USER zabbix WITH PASSWORD '$DB_PASSWORD';"
sudo -u postgres createdb -O zabbix zabbix
zcat /usr/share/zabbix/sql-scripts/postgresql/server.sql.gz | sudo -u zabbix psql -v ON_ERROR_STOP=1 zabbix > /var/log/zabbix/schema-import.log
sed -i 's/^# DBHost=localhost/DBHost=localhost/' /etc/zabbix/zabbix_server.conf
printf '\nDBPassword=%s\n' "$DB_PASSWORD" >> /etc/zabbix/zabbix_server.conf
cat > /etc/zabbix/zabbix_agentd.conf <<'CONF'
PidFile=/run/zabbix/zabbix_agentd.pid
LogFile=/var/log/zabbix/zabbix_agentd.log
LogFileSize=10
DebugLevel=4
Server=127.0.0.1,192.168.56.30
ServerActive=192.168.56.30
Hostname=kolesnikova-aa-1
ListenIP=127.0.0.1,192.168.56.30
Include=/etc/zabbix/zabbix_agentd.d/*.conf
CONF
install -d -m 0750 -o www-data -g www-data /etc/zabbix/web
cat > /etc/zabbix/web/zabbix.conf.php <<PHP
<?php
\$DB['TYPE'] = 'POSTGRESQL';
\$DB['SERVER'] = 'localhost';
\$DB['PORT'] = '0';
\$DB['DATABASE'] = 'zabbix';
\$DB['USER'] = 'zabbix';
\$DB['PASSWORD'] = '$DB_PASSWORD';
\$DB['SCHEMA'] = '';
\$ZBX_SERVER = 'localhost';
\$ZBX_SERVER_PORT = '10051';
\$ZBX_SERVER_NAME = 'Netology Zabbix';
\$IMAGE_FORMAT_DEFAULT = IMAGE_FORMAT_PNG;
PHP
chown www-data:www-data /etc/zabbix/web/zabbix.conf.php
chmod 640 /etc/zabbix/web/zabbix.conf.php
printf 'date.timezone = Europe/Moscow\n' > /etc/php/8.2/apache2/conf.d/99-netology-timezone.ini
systemctl restart zabbix-server zabbix-agent apache2
systemctl enable zabbix-server zabbix-agent apache2
zabbix_server --version | head -1
psql --version
apache2 -v | head -1
systemctl is-active postgresql zabbix-server zabbix-agent apache2
