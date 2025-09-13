#!/bin/bash

echo "[+] Applying OFFLINE lockdown with optional port exceptions..."

# Example: ./lockdown.sh 22 80 443

# Collect allowed ports from script arguments
ALLOWED_PORTS=("$@")

# Disable interfaces
sudo ifconfig awdl0 down 2>/dev/null
sudo ifconfig llw0 down 2>/dev/null
for i in {0..9}; do
  sudo ifconfig utun$i down 2>/dev/null
done

# Disable IPv6 on all network services
services=$(networksetup -listallnetworkservices | tail -n +2)
while IFS= read -r service; do
  echo "Disabling IPv6 on $service..."
  networksetup -setv6off "$service" 2>/dev/null
done <<< "$services"

# PF firewall config
PF_CONF="/etc/pf.conf"
PF_BACKUP="/etc/pf.conf.backup.lockdown"

# Backup pf.conf once
if [ ! -f "$PF_BACKUP" ]; then
  sudo cp "$PF_CONF" "$PF_BACKUP"
fi

# Write lockdown rules
{
  echo "block all"
  echo "set skip on lo0"

  # Allow Expo/Docker dev tools on localhost ports 19000–19010
  pass in proto tcp from any to any port 19000:19010 keep state
  pass out proto tcp from any to any port 19000:19010 keep state

  # Safe defaults for normal browsing
  echo "pass out proto { udp, tcp } from any to any port 53 keep state"   # DNS
  echo "pass out proto tcp from any to any port 80 keep state"            # HTTP
  echo "pass out proto tcp from any to any port 443 keep state"           # HTTPS

  # Email delivery + retrieval
  echo "pass out proto tcp from any to any port 25 keep state"            # SMTP
  echo "pass out proto tcp from any to any port 465 keep state"           # SMTPS
  echo "pass out proto tcp from any to any port 587 keep state"           # SMTP (submission)
  echo "pass out proto tcp from any to any port 110 keep state"           # POP3
  echo "pass out proto tcp from any to any port 995 keep state"           # POP3S
  echo "pass out proto tcp from any to any port 143 keep state"           # IMAP
  echo "pass out proto tcp from any to any port 993 keep state"           # IMAPS

  # Loop over allowed ports
  for port in "${ALLOWED_PORTS[@]}"; do
    echo "pass out proto tcp from any to any port $port keep state"
  done
} | sudo tee "$PF_CONF" >/dev/null

# Enable PF
sudo pfctl -f "$PF_CONF"
sudo pfctl -e

echo "[✓] Lockdown applied. Allowed ports: ${ALLOWED_PORTS[*]:-"(none)"}"
