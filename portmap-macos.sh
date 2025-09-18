#!/usr/bin/env bash
# Autogenerate /etc/PORTMAP.md with static + dynamic port map info

set -euo pipefail

OUT=${OUT:-/etc/PORTMAP.md}
DATE=$(date -u +"%Y-%m-%d %H:%M UTC")
SERVER=$(hostname -f 2>/dev/null || hostname)

SUDO=${SUDO:-}
if [[ -z "$SUDO" ]]; then
  if [[ ${EUID:-$(id -u)} -ne 0 ]] && command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
  else
    SUDO=""
  fi
fi

write_header() {
  cat > "$OUT" <<EOF
# $SERVER Port Allocation Map

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
}

render_ss_table() {
  $SUDO ss -tulwnp 2>/dev/null | awk -v maxlen=40 '
  /LISTEN/ {
    split($5, a, ":");
    port = a[length(a)];
    if (match(port, /^[0-9]+$/)) { } else next;
    proc = "unknown";
    pid = "N/A";

    line = $0;
    if (match(line, /"[^\"]+"/)) {
      proc = substr(line, RSTART + 1, RLENGTH - 2);
    }
    if (match(line, /pid=[0-9]+/)) {
      pid = substr(line, RSTART + 4, RLENGTH - 4);
    }

    key = port ":" pid;
    if (seen[key]) next;
    seen[key] = 1;

    fullcmd = proc;
    if (pid != "N/A") {
      cmd = "ps -p " pid " -o command= 2>/dev/null";
      if ((cmd | getline tmp) > 0) {
        fullcmd = tmp;
      }
      close(cmd);
    }
    if (length(fullcmd) > maxlen) {
      fullcmd = substr(fullcmd, 1, maxlen - 3) "...";
    }

    printf "| %-6s | %-25s | %-40s |\n", port, proc " (pid " pid ")", fullcmd;
  }
  '
}

render_lsof_table() {
  lsof -nP -iTCP -sTCP:LISTEN 2>/dev/null | awk -v maxlen=40 '
  NR == 1 { next }
  {
    portField = $9;
    sub(/.*:/, "", portField);
    if (match(portField, /^[0-9]+$/)) { } else next;
    port = portField;
    pid = $2;
    proc = $1;

    key = port ":" pid;
    if (seen[key]) next;
    seen[key] = 1;

    fullcmd = proc;
    if (match(pid, /^[0-9]+$/)) {
      cmd = "ps -p " pid " -o command= 2>/dev/null";
      if ((cmd | getline tmp) > 0) {
        fullcmd = tmp;
      }
      close(cmd);
    }
    if (length(fullcmd) > maxlen) {
      fullcmd = substr(fullcmd, 1, maxlen - 3) "...";
    }

    printf "| %-6s | %-25s | %-40s |\n", port, proc " (pid " pid ")", fullcmd;
  }
  '
}

render_listeners() {
  if command -v ss >/dev/null 2>&1; then
    render_ss_table
    return
  fi

  if command -v lsof >/dev/null 2>&1; then
    render_lsof_table
    return
  fi

  if command -v netstat >/dev/null 2>&1; then
    $SUDO netstat -anv 2>/dev/null | awk -v maxlen=40 '
    /LISTEN/ {
      split($4, a, ".");
      port = a[length(a)];
      if (match(port, /^[0-9]+$/)) { } else next;
      printf "| %-6s | %-25s | %-40s |\n", port, "(unknown)", "netstat LISTEN entry";
    }
    '
    return
  fi

  echo "| (none) | No tooling | Install ss or lsof for listener enumeration |"
}

append_listener_table() {
  {
    printf "| %-6s | %-25s | %-40s |\n" "Port" "Process" "Command";
    printf "|%s|%s|%s|\n" "-------" "---------------------------" "------------------------------------------";
    render_listeners | sort -t'|' -k2,2
  } >> "$OUT"
}

append_usage_notes() {
  cat >> "$OUT" <<'EOF'

---

## ✅ Usage Notes
- All services should run under **systemd units** (or docker-compose with restart policies) with explicit ports.
- Nginx proxies **only to localhost** ports defined above.
- Update this file immediately when provisioning new services.
EOF
}

write_header
append_listener_table
append_usage_notes

echo "✅ Port map generated at $OUT"
