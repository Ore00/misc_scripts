#!/bin/bash
set -e

# ---------------------------------------
# lockdown.sh — surgical offline lockdown
# ---------------------------------------
# - Default-deny inbound
# - Default-deny outbound IPv6 (allow only what you specify)
# - Keep Wi-Fi functional via explicit DHCP/DNS/ICMP rules
# - Allow web/email/conferencing by default (IPv4)
# - Localhost Expo/Docker ports (19000–19010) on lo0
#
# Args (repeat as needed):
#   in:<port>     -> allow inbound TCP port
#   out:<port>    -> allow outbound TCP (IPv4) port
#   out6:<port>   -> allow outbound TCP (IPv6) port
#
# Examples:
#   sudo ./lockdown.sh
#   sudo ./lockdown.sh in:22 out:22 out:443
#   sudo ./lockdown.sh out6:443
#
# Pair with a restore script to revert PF config.
# ---------------------------------------

echo "[+] Applying lockdown…"

# --- Toggle: also turn off IPv6 at the network service level (safer but optional) ---
DISABLE_V6_SERVICES=true    # set to 'false' if you want to keep macOS IPv6 settings unchanged

# --- Parse arguments ---
ALLOWED_IN_TCP=()
ALLOWED_OUT_TCP4=()
ALLOWED_OUT_TCP6=()

for arg in "$@"; do
  case "$arg" in
    in:*)    ALLOWED_IN_TCP+=("${arg#in:}")   ;;
    out:*)   ALLOWED_OUT_TCP4+=("${arg#out:}") ;;
    out6:*)  ALLOWED_OUT_TCP6+=("${arg#out6:}") ;;
    -h|--help)
      echo "Usage: sudo $0 [in:<port>] [out:<port>] [out6:<port>] ..."
      exit 0
      ;;
  esac
done

# --- Quiet helpers ---
_q() { "$@" >/dev/null 2>&1 || true; }

# --- 1) Disable Apple peer-to-peer + tunnel interfaces (AirDrop, Private Relay/VPN) ---
_q sudo ifconfig awdl0 down
_q sudo ifconfig llw0 down
for i in {0..9}; do _q sudo ifconfig utun$i down; done

# --- 2) Optionally disable IPv6 per network service (prevents v6 leaks via system stack) ---
if [ "$DISABLE_V6_SERVICES" = true ]; then
  services=$(networksetup -listallnetworkservices | tail -n +2 || true)
  while IFS= read -r service; do
    [ -z "$service" ] && continue
    echo "[i] Disabling IPv6 on: $service"
    _q networksetup -setv6off "$service"
  done <<< "$services"
else
  echo "[i] Leaving per-service IPv6 settings unchanged."
fi

# --- 3) PF firewall rules ---
PF_CONF="/etc/pf.conf"
PF_BACKUP="/etc/pf.conf.backup.lockdown"

# Backup pf.conf once
if [ ! -f "$PF_BACKUP" ]; then
  echo "[i] Backing up original PF config to: $PF_BACKUP"
  sudo cp "$PF_CONF" "$PF_BACKUP"
fi

echo "[i] Writing lockdown PF rules to $PF_CONF"
{
  echo "set block-policy drop"
  echo "scrub in all fragment reassemble"

  # Skip localhost filtering
  echo "set skip on lo0"

  # Inbound default-deny
  echo "block in all"

  # Outbound default-deny for IPv6 (we'll allow per-port below)
  echo "block out inet6 all"

  # -------- Local dev (Expo/Docker) on loopback only --------
  echo "pass in  on lo0 proto tcp from any to any port 19000:19010 keep state"
  echo "pass out on lo0 proto tcp from any to any port 19000:19010 keep state"

  # -------- Core networking (so Wi-Fi works) --------
  # DHCP client (stateful will allow server replies)
  echo "pass out proto udp from any port 68 to any port 67 keep state"
  # DNS (UDP/TCP)
  echo "pass out proto { udp, tcp } from any to any port 53 keep state"
  # ICMP/ICMPv6 (neighbor discovery, PMTU, ping)
  echo "pass inet  proto icmp  all keep state"
  echo "pass inet6 proto icmp6 all keep state"

  # -------- Web browsing (IPv4) --------
  echo "pass out inet proto tcp from any to any port 80  keep state"
  echo "pass out inet proto tcp from any to any port 443 keep state"

  # -------- Email (IPv4) --------
  echo "pass out inet proto tcp from any to any port {25,465,587,110,995,143,993} keep state"

  # -------- Conferencing (IPv4) --------
  # Zoom
  echo "pass out inet proto tcp from any to any port {80,443} keep state"
  echo "pass out inet proto udp from any to any port {3478,3479,8801:8810} keep state"
  # Teams
  echo "pass out inet proto udp from any to any port 3478:3481 keep state"
  echo "pass out inet proto udp from any to any port 50000:50059 keep state"
  # Google Meet / Google Voice (WebRTC)
  echo "pass out inet proto udp from any to any port {19302:19309,3478} keep state"
  echo "pass out inet proto udp from any to any port 10000:20000 keep state"

  # -------- Optional inbound exceptions (TCP) --------
  if [ ${#ALLOWED_IN_TCP[@]} -gt 0 ]; then
    for port in "${ALLOWED_IN_TCP[@]}"; do
      if [[ "$port" =~ ^[0-9]+$ ]]; then
        echo "pass in proto tcp from any to any port ${port} keep state"
      fi
    done
  fi

  # -------- Optional outbound TCP (IPv4) exceptions --------
  if [ ${#ALLOWED_OUT_TCP4[@]} -gt 0 ]; then
    for port in "${ALLOWED_OUT_TCP4[@]}"; do
      if [[ "$port" =~ ^[0-9]+$ ]]; then
        echo "pass out inet proto tcp from any to any port ${port} keep state"
      fi
    done
  fi

  # -------- Optional outbound TCP (IPv6) exceptions --------
  if [ ${#ALLOWED_OUT_TCP6[@]} -gt 0 ]; then
    for port in "${ALLOWED_OUT_TCP6[@]}"; do
      if [[ "$port" =~ ^[0-9]+$ ]]; then
        echo "pass out inet6 proto tcp from any to any port ${port} keep state"
      fi
    done
  fi

  # (If you want IPv6 web globally, you could also add:)
  # echo "pass out inet6 proto tcp from any to any port 80  keep state"
  # echo "pass out inet6 proto tcp from any to any port 443 keep state"

} | sudo tee "$PF_CONF" >/dev/null

# Load & enable PF
_q sudo pfctl -f "$PF_CONF"
_q sudo pfctl -e

# Keep macOS application firewall ON (inbound control)
_q sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on
_q sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setblockall on

echo "[✓] Lockdown applied."
echo "    - Inbound default-deny; outbound IPv6 default-deny."
echo "    - Wi-Fi preserved (DHCP/DNS/ICMP allowed)."
echo "    - Web/email/conferencing (IPv4) allowed."
if [ ${#ALLOWED_IN_TCP[@]} -gt 0 ]; then
  echo "    - Inbound TCP exceptions: ${ALLOWED_IN_TCP[*]}"
fi
if [ ${#ALLOWED_OUT_TCP4[@]} -gt 0 ]; then
  echo "    - Outbound TCP (IPv4) exceptions: ${ALLOWED_OUT_TCP4[*]}"
fi
if [ ${#ALLOWED_OUT_TCP6[@]} -gt 0 ]; then
  echo "    - Outbound TCP (IPv6) exceptions: ${ALLOWED_OUT_TCP6[*]}"
fi

echo
echo "[i] Verify rules with: sudo pfctl -sr"
echo "[i] Check default routes: netstat -rn | grep default"
echo "[i] Quick test (IPv4 HTTPS): nc -vz google.com 443"
echo "[i] Quick test (IPv6 HTTPS): nc -6 -vz google.com 443  # should FAIL unless you allowed out6:443"
