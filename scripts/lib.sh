#!/usr/bin/env bash
# Shared helpers. Sourced by every script.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[ -f "$ROOT/config.env" ] || { echo "Missing config.env. Run: cp $ROOT/config.example.env $ROOT/config.env  and edit it."; exit 1; }
# shellcheck disable=SC1091
source "$ROOT/config.env"
chmod 600 "$ROOT/config.env" 2>/dev/null || true   # contains private keys: owner-only

SEQ_DIR="$WORKDIR/sequencer"
LOG_DIR="$WORKDIR/logs"
DEPLOYER_DIR="$WORKDIR/.deployer"
PRESTATE_DIR="$WORKDIR/prestate"
mkdir -p "$WORKDIR" "$LOG_DIR"

RED=$'\033[31m'; GRN=$'\033[32m'; YEL=$'\033[33m'; BLD=$'\033[1m'; RST=$'\033[0m'
info() { echo "${BLD}==>${RST} $*"; }
ok()   { echo "${GRN}OK${RST}  $*"; }
warn() { echo "${YEL}WARN${RST} $*"; }
die()  { echo "${RED}ERROR${RST} $*" >&2; exit 1; }

need_cmd()  { command -v "$1" >/dev/null 2>&1 || die "'$1' not found. Install it first."; }
need_file() { [ -e "$1" ] || die "Missing $1 ${2:-}"; }

l2_chain_hex() { printf '0x%064x' "$L2_CHAIN_ID"; }

# Human time from unix seconds (macOS and Linux)
fmt_time() { date -r "$1" 2>/dev/null || date -d "@$1"; }

no_placeholders() {
  case "$L1_RPC_URL$L1_BEACON_URL" in *YOUR-*) die "Set L1_RPC_URL and L1_BEACON_URL in config.env";; esac
  case "$L2_CHAIN_ID$ADMIN$SEQUENCER$BATCHER$PROPOSER$CHALLENGER" in *YOUR-*) die "Set L2_CHAIN_ID and the 5 role addresses in config.env";; esac
}

# ask_key ENV_VAR "Role" EXPECTED_ADDRESS
# Reads a private key silently (unless already exported), and checks it belongs to the role.
ask_key() {
  local var="$1" role="$2" expected="$3" key addr
  key="$(printenv "$var" || true)"
  if [ -z "$key" ]; then   # then the key from config.env (e.g. ADMIN_PRIVATE_KEY)
    local cfg; cfg="$(echo "$role" | tr '[:lower:]' '[:upper:]')_PRIVATE_KEY"
    key="$(eval "echo \"\${$cfg:-}\"")"
  fi
  if [ -z "$key" ]; then
    read -r -s -p "$role private key (input hidden): " key; echo
  fi
  [[ "$key" =~ ^(0x)?[0-9a-fA-F]{64}$ ]] || die "That is not a 32-byte hex private key."
  [[ "$key" == 0x* ]] || key="0x$key"
  addr=$(cast wallet address --private-key "$key")
  if [ "$(echo "$addr" | tr A-F a-f)" != "$(echo "$expected" | tr A-F a-f)" ]; then
    die "Key is for $addr, but $role in config.env is $expected. Wrong key?"
  fi
  export "$var=$key"
  ok "$role key loaded for $addr"
}

state_addr() { jq -r ".opChainDeployments[0].$1" "$DEPLOYER_DIR/state.json"; }
prestate_hash() { need_file "$PRESTATE_DIR/PRESTATE_HASH" "(run scripts/05-build-prestate.sh)"; cat "$PRESTATE_DIR/PRESTATE_HASH"; }
