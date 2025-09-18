#!/usr/bin/env bash
# Show current listening ports and owning processes
# Useful for comparing against PORTMAP.md

echo "📡 Current Listening Ports on $(hostname)"
echo "========================================="
printf "%-8s %-25s %-30s\n" "PORT" "PROCESS" "COMMAND"

# Use ss to get listening sockets
sudo ss -tulwnp | awk '
/LISTEN/ {
    split($5, a, ":");
    port = a[length(a)];
    # process info is in $7 like "users:(("nginx",pid=750,fd=6))"
    match($7, /\"([^"]+)\"/, arr);
    proc = arr[1];
    match($7, /pid=([0-9]+)/, pidarr);
    pid = pidarr[1];
    if (port ~ /^[0-9]+$/) {
        cmd = "ps -p " pid " -o cmd= 2>/dev/null";
        cmd | getline fullcmd;
        close(cmd);
        printf "%-8s %-25s %-30s\n", port, proc " (pid " pid ")", fullcmd;
    }
}'
