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
  info "Go services (mc-node, mc-batcher, mc-proposer, mc-challenger)"
  (cd "$R" && just mc-node && just mc-batcher && just mc-proposer && just mc-challenger)
  info "mc-deployer v0.8.1 and cannon v1.6.0 (from releases/)"
  (cd "$R" && bash mindchain/scripts/build-tools.sh)
  info "mc-reth and kona-host (Rust, takes a while)"
  (cd "$R/rust" && cargo build --release -p mc-reth --bin mc-reth && cargo build --release --bin kona-host)
elif [ "$MODE" != --copy ]; then
  die "Usage: scripts/build-binaries.sh [--copy]"
fi

info "Copying binaries to $BIN"
copy() { need_file "$1" "(build it first: bash scripts/build-binaries.sh)"; cp "$1" "$BIN/"; ok "$(basename "$1")"; }
copy "$R/mc-node/bin/mc-node"
copy "$R/mc-batcher/bin/mc-batcher"
copy "$R/mc-proposer/bin/mc-proposer"
copy "$R/mc-challenger/bin/mc-challenger"
copy "$R/bin/mc-deployer"
copy "$R/bin/cannon"
copy "$R/rust/target/release/mc-reth"
copy "$R/rust/target/release/kona-host"
chmod +x "$BIN"/*

info "Versions"
"$BIN/mc-deployer" --version; "$BIN/cannon" --version; "$BIN/kona-host" --version
"$BIN/mc-node" --version; "$BIN/mc-challenger" --version
"$BIN/mc-reth" --version | head -1
ok "All binaries are in $BIN"
