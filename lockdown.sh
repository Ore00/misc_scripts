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
  # Loop over allowed ports
  for port in "${ALLOWED_PORTS[@]}"; do
    echo "pass out proto tcp from any to any port $port keep state"
  done
} | sudo tee "$PF_CONF" >/dev/null

# Enable PF
sudo pfctl -f "$PF_CONF"
sudo pfctl -e

echo "[✓] Lockdown applied. Allowed ports: ${ALLOWED_PORTS[*]:-"(none)"}"
