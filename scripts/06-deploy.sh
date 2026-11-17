#!/usr/bin/env bash
# Step 6: commit the prestate, deploy the L1 contracts (continue), export node files, verify.
source "$(dirname "$0")/lib.sh"
no_placeholders
cd "$WORKDIR"
HASH=$(prestate_hash)

if [ -f "$WORKDIR/GENESIS_TIME" ] && [ "$(cat "$WORKDIR/GENESIS_TIME")" -le "$(date +%s)" ]; then
  warn "Genesis time has already passed. continue may still work, but L2 must start immediately after."
fi

info "Committing prestate $HASH"
"$BIN/mc-deployer" prestate --workdir="$DEPLOYER_DIR" --dispute-absolute-prestate="$HASH"

ask_key DEPLOYER_PRIVATE_KEY "Admin" "$ADMIN"   # must be the same key used for prepare
info "mc-deployer continue (deploys the L1 contracts)"
"$BIN/mc-deployer" continue --workdir="$DEPLOYER_DIR" --l1-rpc-url="$L1_RPC_URL"

info "Exporting node files"
"$BIN/mc-deployer" inspect rollup  --workdir="$DEPLOYER_DIR" "$L2_CHAIN_ID" > "$SEQ_DIR/rollup.json"
"$BIN/mc-deployer" inspect genesis --workdir="$DEPLOYER_DIR" "$L2_CHAIN_ID" > "$SEQ_DIR/genesis.json"
[ -f "$SEQ_DIR/jwt.txt" ] || { openssl rand -hex 32 > "$SEQ_DIR/jwt.txt"; chmod 600 "$SEQ_DIR/jwt.txt"; }

info "Genesis must match the prestate configs"
G_ROLLUP=$(jq -r .genesis.l2.hash "$SEQ_DIR/rollup.json")
G_KONA=$(jq -r '.superchains[0].chains[0].genesis.l2.hash' "$PRESTATE_DIR/custom-configs/configs.json")
[ "$G_ROLLUP" = "$G_KONA" ] || die "Genesis changed ($G_ROLLUP vs prestate $G_KONA). Do not start the chain; ask for help."
ok "genesis hash $G_ROLLUP"

jq '.opChainDeployments[0] | {DisputeGameFactoryProxy, AnchorStateRegistryProxy, OptimismPortalProxy, SystemConfigProxy, L1StandardBridgeProxy, initialGameType}' "$DEPLOYER_DIR/state.json"
bash "$ROOT/tools/verify-l1.sh"
ok "Deployed. Back up now: tools/backup.sh"
ok "Then start: run/mc-reth.sh, run/mc-node.sh, run/batcher.sh, run/proposer.sh, run/challenger.sh (one terminal tab each)"
