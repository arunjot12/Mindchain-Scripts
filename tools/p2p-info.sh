#!/usr/bin/env bash
# Run on the SEQUENCER PC (with P2P_ENABLED=true and the nodes running).
# Prints the two values the follower PC puts in its config.env.
source "$(dirname "$0")/../scripts/lib.sh"
[ "$P2P_ENABLED" = true ] || die "Set P2P_ENABLED=true (and P2P_ADVERTISE_IP) in config.env, then restart mc-reth and mc-node."
[ -n "$P2P_ADVERTISE_IP" ] || die "Set P2P_ADVERTISE_IP in config.env (this PC's IP, e.g. ipconfig getifaddr en0)."
PEER=$(cast rpc opp2p_self --rpc-url "http://127.0.0.1:$NODE_RPC_PORT" 2>/dev/null | jq -r .peerID) || true
[ -n "$PEER" ] && [ "$PEER" != null ] || die "mc-node P2P is not running (start run/mc-node.sh with P2P_ENABLED=true)."
ENODE=$(grep -o 'enode://[0-9a-f]*@[^ ,"]*' "$LOG_DIR/mc-reth.log" 2>/dev/null | tail -1 | sed 's/@.*//') || true
[ -n "$ENODE" ] || die "mc-reth enode not found in $LOG_DIR/mc-reth.log (restart run/mc-reth.sh)."
echo
echo "Put these two lines in the FOLLOWER PC's config.env:"
echo
echo "P2P_STATIC_PEERS=\"/ip4/$P2P_ADVERTISE_IP/tcp/$P2P_PORT/p2p/$PEER\""
echo "RETH_TRUSTED_PEERS=\"$ENODE@$P2P_ADVERTISE_IP:$RETH_P2P_PORT\""
echo
echo "This PC must accept incoming TCP+UDP on ports $P2P_PORT and $RETH_P2P_PORT."
