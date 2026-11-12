#!/usr/bin/env bash
# Posts L2 batches to L1 (makes blocks "safe"). Needs the BATCHER key.
source "$(dirname "$0")/../scripts/lib.sh"
no_placeholders
cd "$SEQ_DIR"
ask_key OP_BATCHER_PRIVATE_KEY "Batcher" "$BATCHER"   # passed by env var, not visible in ps
info "mc-batcher ($DA_TYPE)"
"$BIN/mc-batcher" \
  --l1-eth-rpc="$L1_TX_RPC_URL" --l2-eth-rpc="http://127.0.0.1:$RETH_HTTP_PORT" --rollup-rpc="http://127.0.0.1:$NODE_RPC_PORT" \
  --data-availability-type="$DA_TYPE" --target-num-frames=1 --max-channel-duration=5 \
  --poll-interval=2s --sub-safety-margin=6 --num-confirmations=1 --resubmission-timeout=60s \
  --throttle.unsafe-da-bytes-lower-threshold=0 \
  --rpc.addr=127.0.0.1 --rpc.port="$BATCHER_RPC_PORT" \
  2>&1 | tee -a "$LOG_DIR/mc-batcher.log"
