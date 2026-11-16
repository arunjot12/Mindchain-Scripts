#!/usr/bin/env bash
# Starts mc-proposer in the background (this PC's own PROPOSER key). Waits for the node to be synced first.
source "$(dirname "$0")/common.sh"
no_placeholders; need_role_key PROPOSER
( ask_key OP_PROPOSER_PRIVATE_KEY Proposer "$PROPOSER" ) || exit 1
wait_synced
start_bg mc-proposer run/proposer.sh
