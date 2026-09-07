#!/usr/bin/env bash
# Linux Host & Resource Telemetry
echo "=== LINUX HOST & SYSTEM TELEMETRY ==="
echo "- Hostname: $(hostname)"
echo "- Uptime: $(uptime -p 2>/dev/null || uptime)"
echo "- Kernel: $(uname -srm)"
if [ -f /etc/os-release ]; then
  echo "- Distro: $(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '\"')"
fi
if [ -f /proc/meminfo ]; then
  MEM_TOTAL=$(grep MemTotal /proc/meminfo | awk '{print int($2/1024)}')
  MEM_AVAIL=$(grep MemAvailable /proc/meminfo | awk '{print int($2/1024)}')
  echo "- Memory: Available ${MEM_AVAIL}MB / Total ${MEM_TOTAL}MB"
fi
if [ -f /proc/loadavg ]; then
  echo "- CPU Load: $(cat /proc/loadavg | awk '{print $1, $2, $3}')"
fi
