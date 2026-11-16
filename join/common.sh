#!/usr/bin/env bash
# Shared helpers for the join/ scripts (another PC joining an existing MindChain network).
source "$(dirname "${BASH_SOURCE[0]}")/../scripts/lib.sh"

running() { pgrep -f "$BIN/$1( |$)" >/dev/null; }

# start_bg <service> <run script> [args]: start a run/ script in the background (logs in $LOG_DIR)
start_bg() {
  local n="$1"; shift
  if running "$n"; then ok "$n already running"; return; fi
  nohup bash "$ROOT/$@" >/dev/null 2>&1 < /dev/null &
  sleep 3; running "$n" && ok "$n started (log: $LOG_DIR/$n.log)" || die "$n failed to start; see $LOG_DIR/$n.log"
}

uses_own_node() { case "$NODE_RPC_URL" in *127.0.0.1*|*localhost*) return 0;; *) return 1;; esac; }

need_role_key() {   # need_role_key PROPOSER|CHALLENGER : key must be in config.env (background start cannot ask)
  local role="$1" v; v=$(eval "echo \"\${${role}_PRIVATE_KEY:-}\"")
  [ -n "$v" ] || die "Set ${role}_PRIVATE_KEY in config.env."
}

wait_synced() {  # waits until finalized > 0 and l1_gap < 10
  info "Waiting until the node is synced (finalized > 0, l1_gap < 10). Ctrl+C is safe: services keep running."
  while true; do
    local S F G U
    S=$(cast rpc optimism_syncStatus --rpc-url "$NODE_RPC_URL" 2>/dev/null || true)
    if [ -n "$S" ]; then
      F=$(echo "$S" | jq '.finalized_l2.number'); G=$(echo "$S" | jq '.head_l1.number - .current_l1.number'); U=$(echo "$S" | jq '.unsafe_l2.number')
      echo "    $(date +%H:%M:%S)  l2=$U finalized=$F l1_gap=$G"
      [ "$F" -gt 0 ] && [ "$G" -lt 10 ] && { ok "Node synced"; return; }
    else echo "    $(date +%H:%M:%S)  node not answering yet ($NODE_RPC_URL)"; fi
    sleep 30
  done
}
