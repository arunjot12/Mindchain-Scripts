#!/usr/bin/env bash
# Mint native gas token on L2 from the reserve, via L1 deposits (needs ADMIN key + Sepolia ETH).
#   tools/mint-nila.sh <amount-in-tokens> [recipient]      e.g. tools/mint-nila.sh 1000000
source "$(dirname "$0")/../scripts/lib.sh"
no_placeholders
AMOUNT="${1:?Usage: tools/mint-nila.sh <amount> [recipient]}"; TO="${2:-$ADMIN}"
LC=0x420000000000000000000000000000000000002a; RESERVE=0x4200000000000000000000000000000000000029
RETH="http://127.0.0.1:$RETH_HTTP_PORT"; PORTAL=$(state_addr OptimismPortalProxy)
ask_key ADMIN_KEY "Admin" "$ADMIN"
deposit() { cast send "$PORTAL" "depositTransaction(address,uint256,uint64,bool,bytes)" "$LC" 0 200000 false "$1" \
              --rpc-url "$L1_TX_RPC_URL" --private-key "$ADMIN_KEY" | grep -E 'status|transactionHash'; }

if [ "$(cast call "$LC" "minters(address)(bool)" "$ADMIN" --rpc-url "$RETH")" != true ]; then
  info "Authorizing $ADMIN as minter (L1 deposit)"
  deposit "$(cast calldata "authorizeMinter(address)" "$ADMIN")"
  info "Waiting for it on L2..."
  until [ "$(cast call "$LC" "minters(address)(bool)" "$ADMIN" --rpc-url "$RETH")" = true ]; do sleep 15; done
  ok "minter authorized"
fi
BEFORE=$(cast balance "$TO" --rpc-url "$RETH")
info "Minting $AMOUNT $GAS_TOKEN_SYMBOL to $TO (L1 deposit)"
deposit "$(cast calldata "mint(address,uint256)" "$TO" "$(cast to-wei "$AMOUNT")")"
info "Waiting for it on L2 (1-3 min)..."
until [ "$(cast balance "$TO" --rpc-url "$RETH")" != "$BEFORE" ]; do sleep 15; done
ok "$TO balance: $(cast balance "$TO" --ether --rpc-url "$RETH") $GAS_TOKEN_SYMBOL"
ok "reserve left: $(cast balance "$RESERVE" --ether --rpc-url "$RETH") $GAS_TOKEN_SYMBOL"
