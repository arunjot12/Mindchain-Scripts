#!/usr/bin/env bash
# Watches dispute games and counters bad claims. Needs the CHALLENGER key and the prestate file.
source "$(dirname "$0")/../scripts/lib.sh"
no_placeholders
cd "$SEQ_DIR"
DGF=$(state_addr DisputeGameFactoryProxy)
HASH=$(prestate_hash)
need_file "$PRESTATE_DIR/$HASH.bin.gz"
need_file "$SEQ_DIR/depset.json" "(run scripts/04-kona-configs.sh)"
ask_key OP_CHALLENGER_PRIVATE_KEY "Challenger" "$CHALLENGER"
info "mc-challenger: super-cannon-kona, prestate $HASH"
"$BIN/mc-challenger" \
  --l1-eth-rpc="$L1_TX_RPC_URL" --l1-beacon="$L1_BEACON_URL" \
  --l2-eth-rpc="http://127.0.0.1:$RETH_HTTP_PORT" --superroot-rpc="http://127.0.0.1:$NODE_RPC_PORT" \
  --game-factory-address="$DGF" --game-types=super-cannon-kona \
  --datadir="$WORKDIR/challenger-data" \
  --cannon-bin="$BIN/cannon" --cannon-kona-server="$BIN/kona-host" \
  --cannon-kona-prestate="$PRESTATE_DIR/$HASH.bin.gz" \
  --rollup-config=./rollup.json --l2-genesis=./genesis.json --depset-config=./depset.json \
  2>&1 | tee -a "$LOG_DIR/mc-challenger.log"
