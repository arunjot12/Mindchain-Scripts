#!/usr/bin/env bash
# Step 5: build the kona prestate with Docker (Colima). ~30 min first time. Do not interrupt.
# Game type 9 uses the INTEROP prestate (kona-client-int).
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

if command -v colima >/dev/null; then
  colima status >/dev/null 2>&1 || { info "Starting Colima"; colima start; }
fi
docker info >/dev/null 2>&1 || die "Docker is not running (start Colima)."

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
