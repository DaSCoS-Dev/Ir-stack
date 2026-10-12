#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Dascos
set -euo pipefail
BASE=/var/lib/ir-stack/ssh-keys.baseline
TMP="$(mktemp)"; trap 'rm -f "$TMP"' EXIT
/usr/local/sbin/ssh-key-inventory.sh > "$TMP"
install -d -m 700 /var/lib/ir-stack
install -o root -g root -m 600 "$TMP" "$BASE"
logger -t ir-stack-sshkeys -- 'baseline authorized_keys aggiornata esplicitamente'
echo "Baseline SSH aggiornata: $BASE"
