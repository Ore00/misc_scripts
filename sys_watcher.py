#!/usr/bin/env python3
import subprocess
import time
import re
from datetime import datetime

# List of process names to monitor (customize this)
WATCHED_PROCESSES = ["docker", "com.docker", "Code", "code", "com.norto", "norton"]

# How often to check (in seconds)
SCAN_INTERVAL = 10

# Regex to identify IPv6 address patterns
IPV6_PATTERN = re.compile(r"\[([a-fA-F0-9:]+)\]")

def get_active_connections():
    try:
        # Get both IPv4 and IPv6 connections
        result = subprocess.run(
            ["lsof", "-nP", "-iTCP", "-sTCP:ESTABLISHED"],
            capture_output=True, text=True
        )
        return result.stdout.splitlines()
    except Exception as e:
        print(f"[!] Error running lsof: {e}")
        return []

def check_for_matches(lines):
    for line in lines:
        if any(p in line for p in WATCHED_PROCESSES):
            timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            proc = line.split()[0]
            pid = line.split()[1]
            match = IPV6_PATTERN.search(line)
            ipv6_flag = " [IPv6]" if match else ""

            print(f"[{timestamp}] ⚠️  {proc} (PID {pid}) made a connection{ipv6_flag}")
            print(f"→ {line}\n")

def main():
    print("[*] Monitoring for suspicious connections every", SCAN_INTERVAL, "seconds...\n")
    seen = set()

    while True:
        conns = get_active_connections()
        # Only show new connections
        new = [line for line in conns if line not in seen]
        check_for_matches(new)
        seen.update(new)
        time.sleep(SCAN_INTERVAL)

if __name__ == "__main__":
    main()
