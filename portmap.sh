#!/usr/bin/env bash
# Generate /etc/PORTMAP.md with current listening ports in a clean format

OUT=/etc/PORTMAP.md
DATE=$(date -u +"%Y-%m-%d %H:%M UTC")

{
cat <<EOF
# moneill.net Port Allocation Map

Generated: $DATE

This file documents **current service assignments** based on active ports.
It is auto-generated — manual edits will be overwritten.

---

## 📡 Current Assignments
EOF

# Use ss to capture listening ports, skip noise
sudo ss -tulwnp | awk '
/LISTEN/ {
    split($5, a, ":");
    port = a[length(a)];
    if (port ~ /^[0-9]+$/) {
        match($7, /\"([^"]+)\"/, arr);
        proc = arr[1];
        match($7, /pid=([0-9]+)/, pidarr);
        pid = pidarr[1];
        cmd = "ps -p " pid " -o cmd= 2>/dev/null";
        cmd | getline fullcmd;
        close(cmd);
        printf "| %-6s | %-20s | %s |\n", port, proc " (pid " pid ")", fullcmd;
    }
}' | sort -n

} > "$OUT"

echo "✅ Port map generated at $OUT"
