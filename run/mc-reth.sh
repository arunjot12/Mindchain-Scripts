#!/usr/bin/env bash
# Execution client. Start this FIRST. Stop with Ctrl+C.
source "$(dirname "$0")/../scripts/lib.sh"
cd "$SEQ_DIR"
for f in genesis.json jwt.txt; do need_file "$SEQ_DIR/$f" "(run scripts/06-deploy.sh)"; done
NET=()
if [ "$P2P_ENABLED" = true ]; then
  [ -n "$P2P_ADVERTISE_IP" ] && NET+=(--nat="extip:$P2P_ADVERTISE_IP")
  [ -n "$RETH_TRUSTED_PEERS" ] && NET+=(--trusted-peers="$RETH_TRUSTED_PEERS")
fi
info "mc-reth: http 127.0.0.1:$RETH_HTTP_PORT, engine 127.0.0.1:$RETH_AUTH_PORT"
"$BIN/mc-reth" node \
  --chain=./genesis.json --datadir=./mc-reth-data \
  --http --http.addr="$RPC_BIND_ADDR" --http.port="$RETH_HTTP_PORT" --http.api=eth,net,web3,txpool \
  --authrpc.addr=127.0.0.1 --authrpc.port="$RETH_AUTH_PORT" --authrpc.jwtsecret=./jwt.txt \
  --port="$RETH_P2P_PORT" --rollup.disable-tx-pool-gossip ${NET[@]+"${NET[@]}"} \
  2>&1 | tee -a "$LOG_DIR/mc-reth.log"
