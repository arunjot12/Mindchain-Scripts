#!/usr/bin/env bash
# Starts mc-challenger in the background (this PC's own CHALLENGER key). Waits for the node to be synced first.
source "$(dirname "$0")/common.sh"
no_placeholders; need_role_key CHALLENGER
( ask_key OP_CHALLENGER_PRIVATE_KEY Challenger "$CHALLENGER" ) || exit 1
wait_synced
start_bg mc-challenger run/challenger.sh
