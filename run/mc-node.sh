#!/usr/bin/env bash
# Rollup node. Start AFTER mc-reth.
#   run/mc-node.sh            sequencer (builds blocks)
#   run/mc-node.sh verifier   no block building (use to catch up after downtime)
# Do not restart it while catching up: each restart restarts from the last safe block.
source "$(dirname "$0")/../scripts/lib.sh"
no_placeholders
MODE="${1:-sequencer}"
cd "$SEQ_DIR"
for f in rollup.json jwt.txt; do need_file "$SEQ_DIR/$f"; done
cast block-number --rpc-url "http://127.0.0.1:$RETH_HTTP_PORT" >/dev/null 2>&1 || die "mc-reth is not running (start run/mc-reth.sh first)"

SEQ_FLAGS=()
if [ "$MODE" = sequencer ]; then
  SEQ_FLAGS=(--sequencer.enabled --sequencer.l1-confs=4)
  GEN=$(jq -r .genesis.l2_time rollup.json)
  NOW=$(date +%s)
  if [ "$GEN" -gt "$NOW" ]; then
    info "Genesis is at $(fmt_time "$GEN"). Waiting $(( (GEN - NOW) / 60 )) min before starting the sequencer..."
    sleep $(( GEN - NOW + 10 ))
  fi
elif [ "$MODE" != verifier ]; then
  die "Usage: run/mc-node.sh [sequencer|verifier]"
fi
TRUST=(); [ "$L1_TRUST_RPC" = true ] && TRUST=(--l1.trustrpc)

info "mc-node ($MODE): rpc 127.0.0.1:$NODE_RPC_PORT"
"$BIN/mc-node" \
  --l1="$L1_RPC_URL" --l1.rpckind=standard --l1.max-concurrency=20 --l1.rpc-max-batch-size=20 ${TRUST[@]+"${TRUST[@]}"} \
  --l1.beacon="$L1_BEACON_URL" \
  --l2="http://127.0.0.1:$RETH_AUTH_PORT" --l2.jwt-secret=./jwt.txt --l2.enginekind=reth \
  --rollup.config=./rollup.json ${SEQ_FLAGS[@]+"${SEQ_FLAGS[@]}"} --verifier.l1-confs=4 \
  --p2p.disable --rpc.addr=127.0.0.1 --rpc.port="$NODE_RPC_PORT" --safedb.path=./safedb \
  --metrics.enabled --metrics.port="$NODE_METRICS_PORT" --log.level=info \
  2>&1 | tee -a "$LOG_DIR/mc-node.log"
