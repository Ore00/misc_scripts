#!/bin/bash

echo "[+] Restoring ONLINE network state..."

# Re-enable awdl and low-latency wireless interfaces
sudo ifconfig awdl0 up 2>/dev/null
sudo ifconfig llw0 up 2>/dev/null

# Re-enable all utun (VPN/Private Relay) interfaces
for i in {0..9}; do
  sudo ifconfig utun$i up 2>/dev/null
done

# Re-enable IPv6 on all network services (set to automatic)
services=$(networksetup -listallnetworkservices | tail -n +2)

while IFS= read -r service; do
  echo "Enabling IPv6 on $service..."
  networksetup -setv6automatic "$service" 2>/dev/null
done <<< "$services"

# Disable "Block all incoming connections" but leave firewall ON
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setblockall off
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on

echo "[✓] Online network restored."
