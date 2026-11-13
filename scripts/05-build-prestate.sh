#!/usr/bin/env bash
# Step 5: build the kona prestate with Docker (Colima). ~30 min first time. Do not interrupt.
# Game type 9 uses the INTEROP prestate (kona-client-int).
# Colima is stopped automatically when the script ends (success, failure or Ctrl+C)
# to free memory and CPU. Keep it running with: KEEP_COLIMA=true bash scripts/05-build-prestate.sh
source "$(dirname "$0")/lib.sh"
CFG="$PRESTATE_DIR/custom-configs"
for f in configs.json chainList.json depsets.json; do need_file "$CFG/$f" "(run scripts/04-kona-configs.sh)"; done

DF="$MINDCHAIN_REPO/rust/kona/docker/fpvm-prestates/cannon-repro.dockerfile"
grep -q 'rust/op-reth' "$DF" && die "Dockerfile still uses rust/op-reth. Run: git -C $MINDCHAIN_REPO pull origin main"

if [ -f "$WORKDIR/GENESIS_TIME" ]; then
  LEFT=$(( ($(cat "$WORKDIR/GENESIS_TIME") - $(date +%s)) / 60 ))
  [ "$LEFT" -gt 0 ] || die "Genesis time has passed. Redo scripts/03-prepare.sh (new genesis) and step 4."
  info "Minutes until genesis: $LEFT (build ~30 min + deploy ~5 min)"
fi

docker_ok() { docker info >/dev/null 2>&1; }
if ! docker_ok && command -v colima >/dev/null; then
  colima status >/dev/null 2>&1 || { info "Starting Colima (let it finish, do not press Ctrl+C)"; colima start; }
  docker context use colima >/dev/null 2>&1 || true
  if ! docker_ok; then
    warn "Colima is running but Docker does not answer (often after an interrupted start). Restarting Colima..."
    colima stop >/dev/null 2>&1 || colima stop --force >/dev/null 2>&1 || true
    colima start
    docker context use colima >/dev/null 2>&1 || true
  fi
fi
docker_ok || die "Docker is not running. Try: colima stop --force; colima start; docker context use colima"
ok "Docker $(docker info --format '{{.ServerVersion}}')"

stop_colima() {
  [ "${KEEP_COLIMA:-false}" = true ] && { info "Leaving Colima running (KEEP_COLIMA=true)"; return; }
  command -v colima >/dev/null || return
  info "Stopping Colima to free memory/CPU"
  colima stop >/dev/null 2>&1 || colima stop --force >/dev/null 2>&1 || warn "Could not stop Colima; run: colima stop --force"
  colima status >/dev/null 2>&1 && warn "Colima still running" || ok "Colima stopped"
}
trap stop_colima EXIT

OUT="$MINDCHAIN_REPO/rust/kona/prestate-artifacts-cannon-interop"
rm -rf "$MINDCHAIN_REPO/rust/kona/prestate-artifacts-cannon" "$OUT"

info "Building prestate with KONA_CUSTOM_CONFIGS_DIR=$CFG"
cd "$MINDCHAIN_REPO"
export KONA_CUSTOM_CONFIGS_DIR="$CFG"          # absolute path (a ~ path fails)
just reproducible-prestate 2>&1 | tee "$LOG_DIR/prestate-build.log"

FILE=$(ls "$OUT"/0x*.bin.gz 2>/dev/null | head -1 || true)
[ -n "$FILE" ] || die "No interop prestate found in $OUT. See $LOG_DIR/prestate-build.log"
HASH=$(basename "$FILE" .bin.gz)
mkdir -p "$PRESTATE_DIR"
cp "$FILE" "$PRESTATE_DIR/"
[ -f "$OUT/prestate-proof.json" ] && cp "$OUT/prestate-proof.json" "$PRESTATE_DIR/prestate-proof-interop.json"
echo "$HASH" > "$PRESTATE_DIR/PRESTATE_HASH"
ok "Interop prestate (type 9): $HASH"
ok "Saved $PRESTATE_DIR/$HASH.bin.gz"
ok "Next: scripts/06-deploy.sh"
