#!/usr/bin/env bash
# Stops the chain services gracefully, in a safe order.
#   bash tools/stop.sh                  stop everything
#   bash tools/stop.sh mc-batcher       stop only some (mc-reth mc-node mc-batcher mc-proposer mc-challenger)
# Order: challenger, proposer, batcher first; then mc-node; mc-reth last (it holds the L2 database).
source "$(dirname "$0")/../scripts/lib.sh"
ORDER=(mc-challenger mc-proposer mc-batcher mc-node mc-reth)
if [ $# -gt 0 ]; then TARGETS=("$@"); else TARGETS=("${ORDER[@]}"); fi

pids_of() { pgrep -f "$BIN/$1( |$)" || true; }

for svc in "${ORDER[@]}"; do
  case " ${TARGETS[*]} " in *" $svc "*) ;; *) continue;; esac
  PIDS=$(pids_of "$svc")
  if [ -z "$PIDS" ]; then echo "    $svc: not running"; continue; fi
  info "Stopping $svc (pid $(echo $PIDS))"
  kill -INT $PIDS 2>/dev/null || true            # same as Ctrl+C: clean shutdown
  for _ in $(seq 1 30); do [ -z "$(pids_of "$svc")" ] && break; sleep 1; done
  if [ -n "$(pids_of "$svc")" ]; then
    warn "$svc still running after 30 s, sending TERM"
    kill -TERM $(pids_of "$svc") 2>/dev/null || true; sleep 5
  fi
  [ -z "$(pids_of "$svc")" ] && ok "$svc stopped" || warn "$svc did not stop; check: ps aux | grep $svc"
done
