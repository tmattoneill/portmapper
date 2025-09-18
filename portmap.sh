#!/usr/bin/env bash
# Autogenerate /etc/PORTMAP.md with static + dynamic port map info

OUT=/etc/PORTMAP.md
DATE=$(date -u +"%Y-%m-%d %H:%M UTC")

# --- Static Header ---
cat > "$OUT" <<EOF
# <youserver.com> Port Allocation Map

Generated: $DATE

This file documents **reserved port ranges** and **current service assignments**.  
All new apps MUST be assigned a port according to this scheme to avoid conflicts.

---

## 📐 Port Ranges

| Range      | Purpose                          |
|------------|----------------------------------|
| 8100–8199  | FastAPI / Flask backends         |
| 8200–8299  | Dockerized app backends          |
| 8300–8399  | Node / React dev / test servers  |
| 8500–8599  | Data / AI services               |
| 9000–9099  | Infra / admin tools              |
| <1024      | System services (mail, SSH, web) |

---

## 📡 Current Assignments
EOF

# --- Dynamic Listening Ports ---
echo "" >> "$OUT"
printf "| %-6s | %-25s | %-40s |\n" "Port" "Process" "Command" >> "$OUT"
printf "|%s|%s|%s|\n" "-------" "---------------------------" "------------------------------------------" >> "$OUT"

sudo ss -tulwnp | awk '
/LISTEN/ {
    split($5, a, ":");
    port = a[length(a)];
    if (port ~ /^[0-9]+$/) {
        # extract process name from quotes
        if (match($7, /"([^"]+)"/, arr)) {
            proc = arr[1];
        } else {
            proc = "unknown";
        }
        if (match($7, /pid=([0-9]+)/, pidarr)) {
            pid = pidarr[1];
        } else {
            pid = "N/A";
        }
        cmd = "ps -p " pid " -o cmd= 2>/dev/null";
        cmd | getline fullcmd;
        close(cmd);
        printf "| %-6s | %-25s | %-40s |\n", port, proc " (pid " pid ")", fullcmd;
    }
}' | sort -n >> "$OUT"


# --- Footer ---
cat >> "$OUT" <<'EOF'

---

## ✅ Usage Notes
- All services should run under **systemd units** (or docker-compose with restart policies) with explicit ports.  
- Nginx proxies **only to localhost** ports defined above.  
- Update this file immediately when provisioning new services.  
EOF

echo "✅ Port map generated at $OUT"
