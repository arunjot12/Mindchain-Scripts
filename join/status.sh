#!/usr/bin/env bash
# JOIN: what is running on this PC + chain health + check this node matches the chain.
source "$(dirname "$0")/../scripts/lib.sh"
info "Processes"
for s in mc-reth mc-node mc-proposer mc-challenger; do
  pgrep -f "$BIN/$s( |$)" >/dev/null && ok "$s running" || echo "    $s: not running"
done
GEN=$(cast block 0 --field hash --rpc-url "$L2_RPC_URL" 2>/dev/null || true)
EXP=$(jq -r .genesis.l2.hash "$SEQ_DIR/rollup.json")
[ -n "$GEN" ] && { [ "$GEN" = "$EXP" ] && ok "genesis matches the chain ($EXP)" || die "genesis $GEN != chain genesis $EXP: wrong chain!"; }
bash "$ROOT/tools/status.sh"
for s in mc-proposer mc-challenger; do
  [ -f "$LOG_DIR/$s.log" ] && { info "Last lines: $s"; tail -3 "$LOG_DIR/$s.log" | cut -c1-200; }
done
true
