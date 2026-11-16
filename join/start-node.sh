#!/usr/bin/env bash
# Starts this PC's own node in the background: mc-reth + mc-node (follower: never builds blocks).
# Syncs from L1, or fast from the sequencer over P2P if the join pack included its peers.
source "$(dirname "$0")/common.sh"
no_placeholders
uses_own_node || die "NODE_RPC_URL points to another PC's node ($NODE_RPC_URL): no local node needed."
info "Starting mc-reth and mc-node (follower, sync: $SYNC_MODE)"
start_bg mc-reth run/mc-reth.sh
until cast block-number --rpc-url "$L2_RPC_URL" >/dev/null 2>&1; do sleep 2; done
start_bg mc-node run/mc-node.sh verifier
command -v caffeinate >/dev/null && { pgrep -f 'caffeinate -dimsu' >/dev/null || nohup caffeinate -dimsu >/dev/null 2>&1 & } || true
[ "${1:-}" = --no-wait ] || wait_synced
