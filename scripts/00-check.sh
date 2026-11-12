#!/usr/bin/env bash
# Step 0: check tools, binaries and repo before starting.
source "$(dirname "$0")/lib.sh"

info "Command-line tools"
for c in cast jq python3 curl openssl just; do need_cmd "$c"; ok "$c"; done
command -v colima >/dev/null && ok "colima" || warn "colima not found (needed for the prestate build)"

info "MindChain binaries in $BIN"
for b in mc-deployer mc-node mc-reth mc-batcher mc-proposer mc-challenger cannon kona-host; do
  need_file "$BIN/$b" "(build them from the mind-chain repo, see README)"
done
"$BIN/mc-deployer" --version | sed 's/^/    /'
"$BIN/cannon" --version | sed 's/^/    /'
"$BIN/kona-host" --version | sed 's/^/    /'
"$BIN/mc-node" --version | sed 's/^/    /'
"$BIN/mc-challenger" --version | sed 's/^/    /'

info "Repo checks"
DF="$MINDCHAIN_REPO/rust/kona/docker/fpvm-prestates/cannon-repro.dockerfile"
need_file "$DF"
if grep -q 'rust/op-reth' "$DF"; then
  die "$DF still copies rust/op-reth. Run: git -C $MINDCHAIN_REPO pull origin main"
fi
ok "prestate Dockerfile uses mc-reth paths"

info "Config"
no_placeholders
echo "    L2 chain ID: $L2_CHAIN_ID ($(l2_chain_hex))"
echo "    Workdir:     $WORKDIR"
ok "ready"
