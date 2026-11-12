#!/usr/bin/env bash
# Verifies the deployed L1 contracts: respected game type, game impl, bond, prestate.
source "$(dirname "$0")/../scripts/lib.sh"
DGF=$(state_addr DisputeGameFactoryProxy); ASR=$(state_addr AnchorStateRegistryProxy)
HASH=$(prestate_hash); R="$L1_TX_RPC_URL"
RT=$(cast call "$ASR" "respectedGameType()(uint32)" --rpc-url "$R")
IMPL=$(cast call "$DGF" "gameImpls(uint32)(address)" "$RESPECTED_GAME_TYPE" --rpc-url "$R")
BOND=$(cast call "$DGF" "initBonds(uint32)(uint256)" "$RESPECTED_GAME_TYPE" --rpc-url "$R" | awk '{print $1}')
ARGS=$(cast call "$DGF" "gameArgs(uint32)(bytes)" "$RESPECTED_GAME_TYPE" --rpc-url "$R")
[ "$RT" = "$RESPECTED_GAME_TYPE" ] && ok "respected game type $RT" || die "respected game type is $RT"
[ "$IMPL" != 0x0000000000000000000000000000000000000000 ] && ok "game impl $IMPL" || die "no game impl for type $RESPECTED_GAME_TYPE"
ok "init bond $(cast from-wei "$BOND") ETH"
echo "$ARGS" | grep -qi "${HASH#0x}" && ok "prestate $HASH is set on-chain" || die "prestate $HASH NOT found in game args"
