#!/usr/bin/env bash
# Backs up everything needed to run the nodes and the challenger (no databases, no keys).
source "$(dirname "$0")/../scripts/lib.sh"
OUT="$HOME/mindchain-backup-$L2_CHAIN_ID-$(date +%Y%m%d-%H%M).tgz"
cd "$WORKDIR"
tar czf "$OUT" .deployer sequencer/rollup.json sequencer/genesis.json sequencer/depset.json sequencer/jwt.txt \
  prestate bootstrap-superchain.json bootstrap-implementations.json $( [ -f GENESIS_TIME ] && echo GENESIS_TIME )
ok "Backup: $OUT ($(du -h "$OUT" | cut -f1))"
