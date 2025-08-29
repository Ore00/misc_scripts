import subprocess
import time
from datetime import datetime
import os

LOG_DIR = os.path.join(os.path.dirname(__file__), "logs")
os.makedirs(LOG_DIR, exist_ok=True)
LOG_FILE = os.path.join(LOG_DIR, "system_watch_connection_log.txt" )

INTERVAL = 60  # Time between checks in seconds

def log(message):
    """Write message to log file and print it."""
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    entry = f"[{timestamp}] {message}"
    print(entry)
    with open(LOG_FILE, "a") as f:
        f.write(entry + "\n")

def get_connections():
    """Get a list of current network connections with lsof."""
    try:
        output = subprocess.check_output(
            ["lsof", "-nP", "-i", "-sTCP:ESTABLISHED"],
            stderr=subprocess.DEVNULL
        ).decode()
        lines = output.strip().split("\n")[1:]  # Skip header
        return lines
    except Exception as e:
        log(f"Error fetching connections: {e}")
        return []

def parse_connection(line):
    """Parse a line from lsof output."""
    parts = line.split()
    if len(parts) >= 9:
        return {
            "process": parts[0],
            "pid": parts[1],
            "user": parts[2],
            "fd": parts[3],
            "protocol": parts[7] if len(parts) > 7 else "",
            "name": parts[8]
        }
    return {}

def main():
    seen_connections = set()

    log("Starting connection watcher...\n")

    while True:
        connections = get_connections()
        for line in connections:
            conn_info = parse_connection(line)
            conn_key = (conn_info.get("pid"), conn_info.get("name"))
            if conn_key not in seen_connections:
                seen_connections.add(conn_key)
                log(f"New Connection → Process: {conn_info.get('process')} | PID: {conn_info.get('pid')} | "
                    f"Protocol: {conn_info.get('protocol')} | Address: {conn_info.get('name')}")
        time.sleep(INTERVAL)

if __name__ == "__main__":
    main()
