#!/usr/bin/env bash
# Puts every binary the scripts need into ./bin.
#   bash scripts/build-binaries.sh          build everything from the mind-chain repo, then copy to ./bin
#   bash scripts/build-binaries.sh --copy   only copy binaries you already built in the repo
# Needs for building: go, just, rust/cargo, forge (versions in the repo's mise.toml).
source "$(dirname "$0")/lib.sh"
MODE="${1:-build}"
R="$MINDCHAIN_REPO"
need_file "$R/justfile" "(clone it: git clone --recurse-submodules https://github.com/arunjot12/mind-chain.git $R)"
mkdir -p "$BIN"

if [ "$MODE" = build ]; then
  info "Building with the repo script (output: $R/bin)"
  bash "$R/mindchain/scripts/build-all.sh"
elif [ "$MODE" != --copy ]; then
  die "Usage: scripts/build-binaries.sh [--copy]"
fi

info "Copying binaries to $BIN"
copy() { need_file "$1" "(build it: bash $R/mindchain/scripts/build-all.sh)"; cp "$1" "$BIN/"; ok "$(basename "$1")"; }
for b in mc-deployer cannon kona-host mc-node mc-reth mc-batcher mc-proposer mc-challenger; do copy "$R/bin/$b"; done
chmod +x "$BIN"/*

info "Versions"
"$BIN/mc-deployer" --version; "$BIN/cannon" --version; "$BIN/kona-host" --version
"$BIN/mc-node" --version; "$BIN/mc-challenger" --version
"$BIN/mc-reth" --version | head -1
ok "All binaries are in $BIN"
