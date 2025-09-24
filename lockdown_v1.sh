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

   # ---- Core networking essentials ----
  echo "pass out proto udp from any port 68 to any port 67 keep state"   # DHCP client
  echo "pass out proto { udp, tcp } from any to any port 53 keep state" # DNS
  echo "pass inet proto icmp all keep state"                            # ICMP (IPv4 ping)
  echo "pass inet6 proto icmp6 all keep state"                          # ICMPv6

  # ---- Web browsing ----
  echo "pass out proto tcp from any to any port 80 keep state"          # HTTP
  echo "pass out proto tcp from any to any port 443 keep state"         # HTTPS

  # ---- Email ----
  echo "pass out proto tcp from any to any port 25 keep state"          # SMTP
  echo "pass out proto tcp from any to any port 465 keep state"         # SMTPS
  echo "pass out proto tcp from any to any port 587 keep state"         # SMTP (submission)
  echo "pass out proto tcp from any to any port 110 keep state"         # POP3
  echo "pass out proto tcp from any to any port 995 keep state"         # POP3S
  echo "pass out proto tcp from any to any port 143 keep state"         # IMAP
  echo "pass out proto tcp from any to any port 993 keep state"         # IMAPS

  # ---- Zoom ----
  echo "pass out proto tcp from any to any port {80,443} keep state"
  echo "pass out proto udp from any to any port {3478,3479,8801:8810} keep state"

  # ---- Microsoft Teams ----
  echo "pass out proto tcp from any to any port 443 keep state"
  echo "pass out proto udp from any to any port 3478:3481 keep state"
  echo "pass out proto udp from any to any port 50000:50059 keep state"

  # ---- Google Meet ----
  echo "pass out proto tcp from any to any port 443 keep state"
  echo "pass out proto udp from any to any port {19302:19309,3478} keep state"
  # Broader RTP rule (optional, but helps call quality)
  echo "pass out proto udp from any to any port 10000:20000 keep state"

  # ---- Google Voice ----
  # echo "pass out proto tcp from any to any port {80,443} keep state"
  echo "pass out proto udp from any to any port {19302:19309,3478} keep state"
  # echo "pass out proto udp from any to any port 10000:20000 keep state"

  # Allow Expo/Docker dev tools on localhost ports 3000-3020 & 19000–19010
  # echo "pass in proto tcp from any to any port 19000:19010 keep state"
  # echo "pass out proto tcp from any to any port 19000:19010 keep state"
  # echo "pass in proto tcp from any to any port 3000:3020 keep state"
  # echo "pass out proto tcp from any to any port 3000:3020 keep state"
  # echo "pass in proto tcp from any to any port 5000:5010 keep state"
  # echo "pass out proto tcp from any to any port 5000:5010 keep state"
  # echo "pass in proto tcp from any to any port 27017:27020 keep state"
  # echo "pass out proto tcp from any to any port 27017:27020 keep state"


  # Loop over allowed ports
  for port in "${ALLOWED_PORTS[@]}"; do
    echo "pass out proto tcp from any to any port $port keep state"
  done
} | sudo tee "$PF_CONF" >/dev/null

# Enable PF
sudo pfctl -f "$PF_CONF"
sudo pfctl -e

echo "[✓] Lockdown applied. Allowed ports: ${ALLOWED_PORTS[*]:-"(none)"}"
