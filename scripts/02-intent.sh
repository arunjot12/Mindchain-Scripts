#!/usr/bin/env bash
# Step 2: create .deployer/intent.toml from config.env (no manual editing needed).
source "$(dirname "$0")/lib.sh"
cd "$WORKDIR"
need_file bootstrap-superchain.json "(run scripts/01-bootstrap.sh)"
need_file bootstrap-implementations.json "(run scripts/01-bootstrap.sh)"
[ -f "$DEPLOYER_DIR/state.json" ] && grep -q '"deployed": *true' "$DEPLOYER_DIR/state.json" 2>/dev/null && die "This WORKDIR is already deployed."

if [ ! -f "$DEPLOYER_DIR/intent.toml" ]; then
  info "mc-deployer init (chain $L2_CHAIN_ID)"
  "$BIN/mc-deployer" init --l1-chain-id="$L1_CHAIN_ID" --l2-chain-ids="$L2_CHAIN_ID" --workdir="$DEPLOYER_DIR" --intent-type=custom
fi
cp "$DEPLOYER_DIR/intent.toml" "$DEPLOYER_DIR/intent.toml.bak-$(date +%s)"

VERSION=$(sed -n 's/^opDeployerVersion = "\(.*\)"/\1/p' "$DEPLOYER_DIR/intent.toml")
OPCM=$(jq -r .opcmV2Address bootstrap-implementations.json)
SC_PROXY=$(jq -r .superchainConfigProxyAddress bootstrap-superchain.json)

cat > "$DEPLOYER_DIR/intent.toml" <<TOML
configType = "custom"
opDeployerVersion = "$VERSION"
l1ChainID = $L1_CHAIN_ID
fundDevAccounts = false
opcmAddress = "$OPCM"
superchainConfigProxy = "$SC_PROXY"
l1ContractsLocator = "embedded"
l2ContractsLocator = "embedded"
useInterop = false

[[chains]]
  id = "$(l2_chain_hex)"
  baseFeeVaultRecipient = "$ADMIN"
  l1FeeVaultRecipient = "$ADMIN"
  sequencerFeeVaultRecipient = "$ADMIN"
  operatorFeeVaultRecipient = "$ADMIN"
  eip1559DenominatorCanyon = $EIP1559_DENOMINATOR_CANYON
  eip1559Denominator = $EIP1559_DENOMINATOR
  eip1559Elasticity = $EIP1559_ELASTICITY
  gasLimit = $GAS_LIMIT
  operatorFeeScalar = 0
  operatorFeeConstant = 0
  minBaseFee = 0
  daFootprintGasScalar = 0
  [chains.deployOverrides]
    respectedGameType = $RESPECTED_GAME_TYPE
  [chains.roles]
    l1ProxyAdminOwner = "$ADMIN"
    l2ProxyAdminOwner = "$ADMIN"
    systemConfigOwner = "$ADMIN"
    unsafeBlockSigner = "$SEQUENCER"
    batcher = "$BATCHER"
    proposer = "$PROPOSER"
    challenger = "$CHALLENGER"
  [chains.customGasToken]
    name = "$GAS_TOKEN_NAME"
    symbol = "$GAS_TOKEN_SYMBOL"
    initialLiquidity = "$INITIAL_LIQUIDITY"
    liquidityControllerOwner = "$ADMIN"
TOML

grep -qE '0xADMIN|0xSEQ|0xBAT|0xPRO|YOUR-' "$DEPLOYER_DIR/intent.toml" && die "Placeholder left in intent.toml"
ok "Wrote $DEPLOYER_DIR/intent.toml"
cat "$DEPLOYER_DIR/intent.toml"
ok "Check it, then run: scripts/03-prepare.sh"
