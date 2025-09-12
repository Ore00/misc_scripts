#!/bin/bash

echo "[+] Restoring ONLINE state..."

# Re-enable interfaces
sudo ifconfig awdl0 up 2>/dev/null
sudo ifconfig llw0 up 2>/dev/null
for i in {0..9}; do
  sudo ifconfig utun$i up 2>/dev/null
done

# Re-enable IPv6 on all network services
services=$(networksetup -listallnetworkservices | tail -n +2)
while IFS= read -r service; do
  echo "Enabling IPv6 on $service..."
  networksetup -setv6automatic "$service" 2>/dev/null
done <<< "$services"

# Restore pf.conf
PF_CONF="/etc/pf.conf"
PF_BACKUP="/etc/pf.conf.backup.lockdown"

if [ -f "$PF_BACKUP" ]; then
  sudo cp "$PF_BACKUP" "$PF_CONF"
  sudo pfctl -f "$PF_CONF"
fi

# Disable PF if you don’t want it active all the time
sudo pfctl -d 2>/dev/null

echo "[✓] Online state restored."
