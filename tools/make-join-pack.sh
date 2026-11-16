#!/usr/bin/env bash
# Run on the SEQUENCER PC. Creates one file to give to another PC that wants to join this network and run
# its own mc-reth + mc-node, mc-proposer and mc-challenger on this chain.
# Contains: chain files + a pre-filled config. Contains NO private keys.
source "$(dirname "$0")/../scripts/lib.sh"
cd "$WORKDIR"
for f in .deployer/state.json sequencer/rollup.json sequencer/genesis.json sequencer/depset.json prestate/PRESTATE_HASH; do need_file "$f"; done
HASH=$(prestate_hash); need_file "prestate/$HASH.bin.gz"

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
P="$TMP/mindchain-join-$L2_CHAIN_ID"; mkdir -p "$P/chain/sequencer" "$P/chain/prestate" "$P/chain/.deployer"
cp .deployer/state.json "$P/chain/.deployer/"
cp sequencer/rollup.json sequencer/genesis.json sequencer/depset.json "$P/chain/sequencer/"
cp "prestate/$HASH.bin.gz" prestate/PRESTATE_HASH "$P/chain/prestate/"
cp bootstrap-superchain.json bootstrap-implementations.json "$P/chain/" 2>/dev/null || true

# P2P fast-sync peers, if P2P is on here
STATIC=""; TRUSTED=""
if [ "$P2P_ENABLED" = true ] && [ -n "$P2P_ADVERTISE_IP" ]; then
  PEER=$(cast rpc opp2p_self --rpc-url "http://127.0.0.1:$NODE_RPC_PORT" 2>/dev/null | jq -r .peerID 2>/dev/null || true)
  ENODE=$(grep -o 'enode://[0-9a-f]*@' "$LOG_DIR/mc-reth.log" 2>/dev/null | tail -1 | sed 's/@$//' || true)
  [ -n "$PEER" ] && [ "$PEER" != null ] && STATIC="/ip4/$P2P_ADVERTISE_IP/tcp/$P2P_PORT/p2p/$PEER"
  [ -n "$ENODE" ] && TRUSTED="$ENODE@$P2P_ADVERTISE_IP:$RETH_P2P_PORT"
fi
MYIP="${P2P_ADVERTISE_IP:-$(ipconfig getifaddr en0 2>/dev/null || hostname -I 2>/dev/null | awk '{print $1}' || true)}"

L2_CHAIN_ID="$L2_CHAIN_ID" ADMIN="$ADMIN" SEQUENCER="$SEQUENCER" BATCHER="$BATCHER" \
STATIC="$STATIC" TRUSTED="$TRUSTED" MYIP="$MYIP" GAS_TOKEN_NAME="$GAS_TOKEN_NAME" GAS_TOKEN_SYMBOL="$GAS_TOKEN_SYMBOL" \
python3 - "$ROOT/config.example.env" "$P/config.join.env" <<'PY'
import os, re, sys
e = os.environ; s = open(sys.argv[1]).read()
def put(k, v): 
    global s; s = re.sub(rf'^{k}=.*$', f'{k}={v}', s, flags=re.M)
s = s.replace("# MindChain deployment config TEMPLATE.", f"# MindChain JOIN config for chain {e['L2_CHAIN_ID']} (proposer + challenger + own node).")
put('L2_CHAIN_ID', e['L2_CHAIN_ID'])
put('WORKDIR', f'"$HOME/mindchain-{e["L2_CHAIN_ID"]}"')
for k in ('ADMIN', 'SEQUENCER', 'BATCHER'): put(k, f'"{e[k]}"          # this chain\'s address: do not change')
put('PROPOSER', '"0xYOUR-PROPOSER-ADDRESS"        # NEW address for this PC (cast wallet new)')
put('CHALLENGER', '"0xYOUR-CHALLENGER-ADDRESS"      # NEW address for this PC (cast wallet new)')
put('GAS_TOKEN_NAME', f'"{e["GAS_TOKEN_NAME"]}"'); put('GAS_TOKEN_SYMBOL', f'"{e["GAS_TOKEN_SYMBOL"]}"')
if e['STATIC'] and e['TRUSTED']:
    put('P2P_ENABLED', 'true'); put('SYNC_MODE', 'execution-layer')
    put('P2P_STATIC_PEERS', f'"{e["STATIC"]}"'); put('RETH_TRUSTED_PEERS', f'"{e["TRUSTED"]}"')
    put('P2P_ADVERTISE_IP', '""                # this PC\'s IP (ipconfig getifaddr en0)')
ip = e.get('MYIP') or '<SEQUENCER-PC-IP>'
s += f'''
# Option A (testing only): no own node, use the sequencer PC's node instead.
# Needs RPC_BIND_ADDR=0.0.0.0 on the sequencer PC. Uncomment both lines:
# L2_RPC_URL="http://{ip}:9545"
# NODE_RPC_URL="http://{ip}:8547"
'''
open(sys.argv[2], 'w').write(s)
PY
OUT="$HOME/mindchain-join-$L2_CHAIN_ID-$(date +%Y%m%d-%H%M).tgz"
tar czf "$OUT" -C "$TMP" "mindchain-join-$L2_CHAIN_ID"
grep -qE '0x[0-9a-fA-F]{64}"' "$P/config.join.env" && die "Refusing: a private key ended up in the pack"
ok "Join pack: $OUT"
[ -n "$STATIC" ] && ok "Includes P2P fast-sync peers (the joining node syncs from this PC in minutes)" \
                 || warn "No P2P peers included (P2P_ENABLED=false here): the joining node will sync from L1 only (slower)"
echo "Give this file + the scripts folder (without config.env) to the other PC. It runs: bash join/setup.sh <file>"
