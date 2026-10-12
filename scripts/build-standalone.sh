#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Dascos
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/dist/install-ir-stack.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
mkdir -p "$ROOT/dist" "$TMP/ir-stack"
cp -a "$ROOT/install.sh" "$ROOT/VERSION" "$ROOT/lib" "$ROOT/src" "$ROOT/integrations" "$TMP/ir-stack/"
tar -C "$TMP" -czf "$TMP/payload.tgz" ir-stack
cat > "$OUT" <<'HEADER'
#!/usr/bin/env bash
set -Eeuo pipefail
tmp="$(mktemp -d)"
cleanup(){ rm -rf "$tmp"; }
trap cleanup EXIT
line="$(awk '/^__IR_STACK_ARCHIVE_BELOW__$/ {print NR+1; exit}' "$0")"
tail -n +"$line" "$0" | base64 -d | tar -xzf - -C "$tmp"
set +e
bash "$tmp/ir-stack/install.sh" "$@"
rc=$?
set -e
exit "$rc"
__IR_STACK_ARCHIVE_BELOW__
HEADER
base64 "$TMP/payload.tgz" >> "$OUT"
chmod 755 "$OUT"
echo "Creato: $OUT"
