#!/bin/bash
# Stops the running Teiserver Phoenix server without restarting the container.
# This container has no pkill/pgrep, so we locate the process via /proc.

set -e

found=0
for d in /proc/[0-9]*; do
  pid=${d#/proc/}
  # Read the process command line (NUL-separated args) and match the phx.server run.
  if grep -qa 'phx.server' "$d/cmdline" 2>/dev/null; then
    echo "Stopping server (PID $pid)..."
    kill "$pid"
    found=1
  fi
done

if [ "$found" -eq 0 ]; then
  echo "No running Phoenix server found."
  exit 0
fi

# Wait for port 4000 (hex 0FA0) to close.
for i in $(seq 1 10); do
  if grep -qi ':0FA0' <(cat /proc/net/tcp /proc/net/tcp6 2>/dev/null | awk '{print $2}'); then
    sleep 1
  else
    echo "Server stopped."
    exit 0
  fi
done

echo "Server process signalled, but port 4000 is still bound after 10s."
exit 1
