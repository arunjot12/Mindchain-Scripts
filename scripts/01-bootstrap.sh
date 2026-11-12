#!/usr/bin/env bash
# Step 1: deploy the shared Superchain contracts and the OPCM implementations on L1.
# Run once per environment. Needs the ADMIN key and ~1 Sepolia ETH on it.
source "$(dirname "$0")/lib.sh"
no_placeholders
cd "$WORKDIR"

if [ -f bootstrap-superchain.json ] || [ -f bootstrap-implementations.json ]; then
  die "bootstrap files already exist in $WORKDIR. Use a new WORKDIR for a fresh deployment."
fi
ask_key DEPLOYER_PRIVATE_KEY "Admin" "$ADMIN"

info "Bootstrapping superchain (owner and guardian: $ADMIN)"
"$BIN/mc-deployer" bootstrap superchain \
  --l1-rpc-url="$L1_RPC_URL" \
  --superchain-proxy-admin-owner="$ADMIN" --guardian="$ADMIN" \
  --no-verify --outfile=./bootstrap-superchain.json

SC_PROXY=$(jq -r .superchainConfigProxyAddress bootstrap-superchain.json)
SC_ADMIN=$(jq -r .proxyAdminAddress bootstrap-superchain.json)
[ "$SC_PROXY" != null ] && [ "$SC_ADMIN" != null ] || die "bootstrap-superchain.json is missing addresses"

info "Bootstrapping implementations (OPCM). No custom timers: type 9 needs the standard ones."
"$BIN/mc-deployer" bootstrap implementations \
  --l1-rpc-url="$L1_RPC_URL" \
  --superchain-config-proxy="$SC_PROXY" --superchain-proxy-admin="$SC_ADMIN" \
  --l1-proxy-admin-owner="$ADMIN" --challenger="$CHALLENGER" \
  --no-verify --outfile=./bootstrap-implementations.json

OPCM=$(jq -r .opcmV2Address bootstrap-implementations.json)
[ "$OPCM" != null ] || die "opcmV2Address missing in bootstrap-implementations.json"

info "Checking ownership on L1"
OWNER=$(cast call "$SC_ADMIN" "owner()(address)" --rpc-url "$L1_RPC_URL")
[ "$(echo "$OWNER" | tr A-F a-f)" = "$(echo "$ADMIN" | tr A-F a-f)" ] || die "ProxyAdmin owner is $OWNER, expected $ADMIN"
ok "superchainConfigProxy = $SC_PROXY"
ok "opcm (v2)             = $OPCM"
ok "Next: scripts/02-intent.sh"
