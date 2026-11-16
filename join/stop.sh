#!/usr/bin/env bash
# JOIN: stop mc-challenger, mc-proposer, then mc-node and mc-reth (safe order).
source "$(dirname "$0")/../scripts/lib.sh"
bash "$ROOT/tools/stop.sh" mc-challenger mc-proposer mc-node mc-reth
pkill -f 'caffeinate -dimsu' 2>/dev/null || true
