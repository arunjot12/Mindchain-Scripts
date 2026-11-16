#!/usr/bin/env bash
# Starts everything for joining the network, in order: mc-reth + mc-node -> (synced) -> mc-proposer -> mc-challenger.
# To run only some: start-node.sh, start-proposer.sh, start-challenger.sh
source "$(dirname "$0")/common.sh"
no_placeholders; need_role_key PROPOSER; need_role_key CHALLENGER
( ask_key OP_PROPOSER_PRIVATE_KEY Proposer "$PROPOSER" && ask_key OP_CHALLENGER_PRIVATE_KEY Challenger "$CHALLENGER" ) || exit 1
[ -n "$(eval 'echo "${ADMIN_PRIVATE_KEY:-}${BATCHER_PRIVATE_KEY:-}"')" ] && warn "A joining PC should not hold the admin or batcher key."
if uses_own_node; then bash "$ROOT/join/start-node.sh" --no-wait; else info "Using another PC's node: $NODE_RPC_URL"; fi
wait_synced
start_bg mc-proposer run/proposer.sh
start_bg mc-challenger run/challenger.sh
ok "Running. Check: bash join/status.sh   Stop: bash join/stop.sh"
