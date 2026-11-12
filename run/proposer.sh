#!/usr/bin/env bash
# Creates type-9 dispute games (0.08 ETH bond each). Needs the PROPOSER key.
# Start only when mc-node has caught up (tools/status.sh shows gap < 10).
source "$(dirname "$0")/../scripts/lib.sh"
no_placeholders
cd "$SEQ_DIR"
DGF=$(state_addr DisputeGameFactoryProxy)
ask_key OP_PROPOSER_PRIVATE_KEY "Proposer" "$PROPOSER"
info "mc-proposer: game type $RESPECTED_GAME_TYPE every $PROPOSAL_INTERVAL, factory $DGF"
"$BIN/mc-proposer" \
  --l1-eth-rpc="$L1_TX_RPC_URL" --superroot-rpcs="http://127.0.0.1:$NODE_RPC_PORT" \
  --game-factory-address="$DGF" --game-type="$RESPECTED_GAME_TYPE" \
  --proposal-interval="$PROPOSAL_INTERVAL" --wait-node-sync=true \
  --rpc.addr=127.0.0.1 --rpc.port="$PROPOSER_RPC_PORT" \
  2>&1 | tee -a "$LOG_DIR/mc-proposer.log"
