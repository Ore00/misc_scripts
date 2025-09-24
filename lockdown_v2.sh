#!/bin/bash
set -e

echo "[+] Applying OFFLINE lockdown with safe defaults and optional port exceptions..."

# Collect optional user-specified TCP ports (space separated), e.g. "22 8080"
ALLOWED_PORTS=("$@")

# 1) Disable Apple peer-to-peer + low-latency wireless interfaces (AirDrop, etc.)
sudo ifconfig awdl0 down 2>/dev/null || true
sudo ifconfig llw0 down 2>/dev/null || true

# 2) Disable VPN / Private Relay / other tunnel interfaces
for i in {0..9}; do
  sudo ifconfig utun$i down 2>/dev/null || true
done

# 3) Disable IPv6 on ALL configured network services (safer default)
services=$(networksetup -listallnetworkservices | tail -n +2 || true)
while IFS= read -r service; do
  # skip blank lines or disabled services
  [ -z "$service" ] && continue
  echo "[i] Disabling IPv6 on: $service"
  networksetup -setv6off "$service" 2>/dev/null || true
done <<< "$services"

# 4) PF: default-deny + safe defaults + conferencing + localhost dev ports
PF_CONF="/etc/pf.conf"
PF_BACKUP="/etc/pf.conf.backup.lockdown"

# Backup original PF rules once
if [ ! -f "$PF_BACKUP" ]; then
  echo "[i] Backing up original PF rules to $PF_BACKUP"
  sudo cp "$PF_CONF" "$PF_BACKUP"
fi

echo "[i] Writing lockdown PF rules to $PF_CONF"
{
  echo "block all"
  # Always allow localhost traffic
  echo "set skip on lo0"

  # ---- Keep localhost Expo/Docker dev tools usable (only on lo0) ----
  echo "pass in  on lo0 proto tcp from any to any port 19000:19010 keep state"
  echo "pass out on lo0 proto tcp from any to any port 19000:19010 keep state"

  # ---- CORE networking (so Wi-Fi works) ----
  echo "pass out proto udp from any port 68 to any port 67 keep state"   # DHCP client
  echo "pass out proto { udp, tcp } from any to any port 53 keep state" # DNS
  echo "pass inet  proto icmp  all keep state"                          # ICMPv4
  echo "pass inet6 proto icmp6 all keep state"                          # ICMPv6

  # ---- Web browsing ----
  echo "pass out proto tcp from any to any port 80  keep state"         # HTTP
  echo "pass out proto tcp from any to any port 443 keep state"         # HTTPS

  # ---- Email ----
  echo "pass out proto tcp from any to any port 25  keep state"         # SMTP
  echo "pass out proto tcp from any to any port 465 keep state"         # SMTPS
  echo "pass out proto tcp from any to any port 587 keep state"         # SMTP (submission)
  echo "pass out proto tcp from any to any port 110 keep state"         # POP3
  echo "pass out proto tcp from any to any port 995 keep state"         # POP3S
  echo "pass out proto tcp from any to any port 143 keep state"         # IMAP
  echo "pass out proto tcp from any to any port 993 keep state"         # IMAPS

  # ---- Conferencing: Zoom ----
  echo "pass out proto tcp from any to any port {80,443} keep state"
  echo "pass out proto udp from any to any port {3478,3479,8801:8810} keep state"

  # ---- Conferencing: Microsoft Teams ----
  echo "pass out proto tcp from any to any port 443 keep state"
  echo "pass out proto udp from any to any port 3478:3481 keep state"
  echo "pass out proto udp from any to any port 50000:50059 keep state"

  # ---- Conferencing: Google Meet / Google Voice (WebRTC) ----
  echo "pass out proto tcp from any to any port 443 keep state"
  echo "pass out proto udp from any to any port {19302:19309,3478} keep state"
  # Broader RTP range (improves P2P quality; comment out if you want stricter)
  echo "pass out proto udp from any to any port 10000:20000 keep state"

  # ---- User-specified extra TCP ports (outbound) ----
  if [ ${#ALLOWED_PORTS[@]} -gt 0 ]; then
    for port in "${ALLOWED_PORTS[@]}"; do
      # numeric sanity check
      if [[ "$port" =~ ^[0-9]+$ ]]; then
        echo "pass out proto tcp from any to any port ${port} keep state"
      fi
    done
  fi
} | sudo tee "$PF_CONF" >/dev/null

# Load & enable PF rules
sudo pfctl -f "$PF_CONF" >/dev/null
sudo pfctl -e         >/dev/null 2>&1 || true

# Keep macOS firewall on as well (inbound control)
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on >/dev/null 2>&1 || true
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setblockall on    >/dev/null 2>&1 || true

echo "[✓] Lockdown applied."
echo "    - PF default-deny active with safe defaults (web, mail, conferencing, DHCP/DNS/ICMP)."
echo "    - Expo/Docker localhost ports 19000–19010 allowed on lo0 only."
echo "    - IPv6 disabled on all services; utun/awdl/llw down."
if [ ${#ALLOWED_PORTS[@]} -gt 0 ]; then
  echo "    - Extra allowed TCP ports: ${ALLOWED_PORTS[*]}"
fi
