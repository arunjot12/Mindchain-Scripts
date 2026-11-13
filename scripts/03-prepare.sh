#!/usr/bin/env bash
# Step 3: prepare. Fixes the genesis time and writes rollup.json + genesis.json.
# From here the clock runs: steps 4-6 must finish before genesis time.
source "$(dirname "$0")/lib.sh"
no_placeholders
cd "$WORKDIR"
need_file "$DEPLOYER_DIR/intent.toml" "(run scripts/02-intent.sh)"
grep -qE '0xADMIN|0xSEQ|0xBAT|0xPRO' "$DEPLOYER_DIR/intent.toml" && die "Placeholder left in intent.toml"

ask_key DEPLOYER_PRIVATE_KEY "Admin" "$ADMIN"   # the same key must be used for continue (step 6)

# mc-deployer sets genesis = (time of the L1 "safe" block) + offset. The safe block is ~6-12 min old,
# so we add its age to the offset: genesis lands GENESIS_DELAY_MINUTES after now.
if [ -n "${GENESIS_DELAY_MINUTES:-}" ]; then
  SAFE_TS=$(cast block safe --field timestamp --rpc-url "$L1_RPC_URL")
  AGE=$(( $(date +%s) - SAFE_TS ))
  OFFSET=$(( AGE + GENESIS_DELAY_MINUTES * 60 ))
  info "L1 safe block is $((AGE / 60)) min old -> offset ${OFFSET}s = genesis in ~${GENESIS_DELAY_MINUTES} min"
  [ "$GENESIS_DELAY_MINUTES" -lt 12 ] && warn "Under 12 min is very tight: steps 4-6 must finish before genesis."
else
  OFFSET="${GENESIS_TIME_OFFSET:?Set GENESIS_DELAY_MINUTES in config.env}"
fi

info "mc-deployer prepare (genesis offset ${OFFSET}s)"
"$BIN/mc-deployer" prepare --workdir="$DEPLOYER_DIR" --l1-rpc-url="$L1_RPC_URL" --genesis-time-offset="$OFFSET"

mkdir -p "$SEQ_DIR"
"$BIN/mc-deployer" inspect rollup  --workdir="$DEPLOYER_DIR" "$L2_CHAIN_ID" > "$SEQ_DIR/rollup.json"
"$BIN/mc-deployer" inspect genesis --workdir="$DEPLOYER_DIR" "$L2_CHAIN_ID" > "$SEQ_DIR/genesis.json"

GT=$(jq -r '.opChainDeployments[0].initialGameType' "$DEPLOYER_DIR/state.json")
[ "$GT" = "$RESPECTED_GAME_TYPE" ] || die "initialGameType is $GT, expected $RESPECTED_GAME_TYPE (respectedGameType must be under [chains.deployOverrides])"
GEN=$(jq -r .genesis.l2_time "$SEQ_DIR/rollup.json")
LEFT=$(( (GEN - $(date +%s)) / 60 ))

ok "initialGameType = $GT"
ok "L1 anchor block = $(jq -r .genesis.l1.number "$SEQ_DIR/rollup.json")"
echo
echo "${BLD}GENESIS TIME: $(fmt_time "$GEN")  (in ~$LEFT minutes)${RST}"
echo "Steps 4, 5 and 6 must finish before this time. Run them NOW, back to back:"
echo "  bash scripts/04-kona-configs.sh && bash scripts/05-build-prestate.sh && bash scripts/06-deploy.sh"
echo "$GEN" > "$WORKDIR/GENESIS_TIME"
