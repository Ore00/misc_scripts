#!/bin/bash

echo "[+] Applying OFFLINE lockdown..."

# Disable awdl and low-latency wireless interfaces
sudo ifconfig awdl0 down 2>/dev/null
sudo ifconfig llw0 down 2>/dev/null

# Disable all utun (VPN/Private Relay) interfaces
for i in {0..9}; do
  sudo ifconfig utun$i down 2>/dev/null
done

# Disable IPv6 on all known network services
services=$(networksetup -listallnetworkservices | tail -n +2)  # skip the header

while IFS= read -r service; do
  echo "Disabling IPv6 on $service..."
  networksetup -setv6off "$service" 2>/dev/null
done <<< "$services"

# Enable firewall and block all incoming connections
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setblockall on

echo "[✓] Offline lockdown applied."

# Optional: Kill any remaining established TCP connections
echo "[i] Killing active TCP connection processes..."
PIDS=$(netstat -anv | grep ESTABLISHED | awk '{print $8}' | grep -E '^[0-9]+$' | sort -u)
for pid in $PIDS; do
  sudo kill -9 "$pid" 2>/dev/null
done
