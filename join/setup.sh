#!/usr/bin/env bash
# JOIN, step 1: unpack the join pack received from the network operator (sequencer PC).
#   bash join/setup.sh ~/Downloads/mindchain-join-981-YYYYMMDD-HHMM.tgz
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PACK="${1:?Usage: bash join/setup.sh <mindchain-join-...tgz>}"
[ -f "$PACK" ] || { echo "ERROR no such file: $PACK"; exit 1; }
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
tar xzf "$PACK" -C "$TMP"
SRC=$(ls -d "$TMP"/mindchain-join-* | head -1)
[ -f "$SRC/config.join.env" ] || { echo "ERROR not a MindChain join pack"; exit 1; }

if [ -f "$ROOT/config.env" ]; then
  echo "config.env already exists: keeping it (the pack's config is saved as config.join.env)"
  cp "$SRC/config.join.env" "$ROOT/config.join.env"
else
  cp "$SRC/config.join.env" "$ROOT/config.env"; chmod 600 "$ROOT/config.env"
  echo "Created config.env from the pack"
fi
source "$ROOT/scripts/lib.sh"      # reads config.env (WORKDIR etc.)

mkdir -p "$WORKDIR"
cp -R "$SRC/chain/." "$WORKDIR/"
[ -f "$SEQ_DIR/jwt.txt" ] || { openssl rand -hex 32 > "$SEQ_DIR/jwt.txt"; chmod 600 "$SEQ_DIR/jwt.txt"; }
CHAIN=$(jq -r .l2_chain_id "$SEQ_DIR/rollup.json")
[ "$CHAIN" = "$L2_CHAIN_ID" ] || die "Pack is for chain $CHAIN but config.env says $L2_CHAIN_ID"
ok "Chain $CHAIN files in $WORKDIR (genesis $(jq -r .genesis.l2.hash "$SEQ_DIR/rollup.json"))"

missing=""; for b in mc-node mc-reth mc-proposer mc-challenger cannon kona-host; do [ -x "$BIN/$b" ] || missing="$missing $b"; done
[ -z "$missing" ] && ok "Binaries present in $BIN" || warn "Missing binaries:$missing  -> copy them into $BIN or run: bash scripts/build-binaries.sh"

echo
echo "${BLD}Now edit $ROOT/config.env:${RST}"
echo "  1. L1_RPC_URL, L1_TX_RPC_URL, L1_BEACON_URL   (your own Sepolia endpoints)"
echo "  2. PROPOSER / CHALLENGER                      (NEW addresses: cast wallet new)"
echo "     PROPOSER_PRIVATE_KEY / CHALLENGER_PRIVATE_KEY"
[ "$P2P_ENABLED" = true ] && echo "  3. P2P_ADVERTISE_IP                            (this PC's IP: ipconfig getifaddr en0)"
echo "Fund the new proposer and challenger with >= 0.5 Sepolia ETH each. Then: bash join/start-all.sh  (or start-node.sh, start-proposer.sh, start-challenger.sh)"
