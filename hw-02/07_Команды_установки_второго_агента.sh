#!/bin/bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y wget ca-certificates
cd /tmp
wget -q https://repo.zabbix.com/zabbix/7.4/release/debian/pool/main/z/zabbix-release/zabbix-release_latest_7.4+debian12_all.deb
dpkg -i zabbix-release_latest_7.4+debian12_all.deb
apt-get update
apt-get install -y zabbix-agent
cat > /etc/zabbix/zabbix_agentd.conf <<'CONF'
PidFile=/run/zabbix/zabbix_agentd.pid
LogFile=/var/log/zabbix/zabbix_agentd.log
LogFileSize=10
DebugLevel=4
Server=192.168.56.30
ServerActive=192.168.56.30
Hostname=kolesnikova-aa-2
ListenIP=127.0.0.1,192.168.56.31
Include=/etc/zabbix/zabbix_agentd.d/*.conf
CONF
systemctl restart zabbix-agent
systemctl enable zabbix-agent
zabbix_agentd --version | head -1
systemctl is-active zabbix-agent
