#!/usr/bin/env bash
# Health check for the whole stack. Safe to run any time.
source "$(dirname "$0")/../scripts/lib.sh"
RETH="http://127.0.0.1:$RETH_HTTP_PORT"; NODE="http://127.0.0.1:$NODE_RPC_PORT"

info "mc-reth"
if B=$(cast block-number --rpc-url "$RETH" 2>/dev/null); then ok "block $B, chain id $(cast chain-id --rpc-url "$RETH")"; else warn "not reachable"; fi

info "mc-node"
if S=$(cast rpc optimism_syncStatus --rpc-url "$NODE" 2>/dev/null); then
  echo "$S" | jq '{unsafe: .unsafe_l2.number, safe: .safe_l2.number, finalized: .finalized_l2.number,
                   current_l1: .current_l1.number, head_l1: .head_l1.number, l1_gap: (.head_l1.number - .current_l1.number)}'
  GAP=$(echo "$S" | jq '.head_l1.number - .current_l1.number')
  [ "$GAP" -lt 10 ] && ok "caught up with L1" || warn "behind L1 by $GAP blocks (do not restart mc-node; proposer waits)"
else warn "not reachable"; fi

if [ -f "$DEPLOYER_DIR/state.json" ] && [ "$(state_addr DisputeGameFactoryProxy)" != null ]; then
  info "Batcher on L1"
  echo "    nonce $(cast nonce "$BATCHER" --rpc-url "$L1_TX_RPC_URL"), balance $(cast balance "$BATCHER" --ether --rpc-url "$L1_TX_RPC_URL") ETH"
  info "Dispute games"
  DGF=$(state_addr DisputeGameFactoryProxy)
  N=$(cast call "$DGF" "gameCount()(uint256)" --rpc-url "$L1_TX_RPC_URL")
  echo "    gameCount $N"
  if [ "$N" -gt 0 ]; then
    G=$(cast call "$DGF" "gameAtIndex(uint256)(uint32,uint64,address)" $((N-1)) --rpc-url "$L1_TX_RPC_URL")
    echo "    latest: $(echo $G)"
  fi
  info "Proposer / challenger balances (ETH)"
  echo "    proposer $(cast balance "$PROPOSER" --ether --rpc-url "$L1_TX_RPC_URL"), challenger $(cast balance "$CHALLENGER" --ether --rpc-url "$L1_TX_RPC_URL")"
fi

info "Recent errors (mc-node)"
[ -f "$LOG_DIR/mc-node.log" ] && { grep -E 'EROR|ERROR' "$LOG_DIR/mc-node.log" | grep -v 'Failed to get L1 origin' | tail -5 || true; }
true
