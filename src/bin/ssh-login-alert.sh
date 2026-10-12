#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Dascos
set -euo pipefail
. /usr/local/lib/ir-stack/common.sh
ir_load_config

STATE_DIR="/var/lib/ir-stack/ssh-login-alert"
STATE_FILE="$STATE_DIR/last_cursor"
LOCK_FILE="/run/ir-stack/ssh-login-alert.lock"
TMP_FILE="$(mktemp)"
ERR_FILE="$(mktemp)"
trap 'rm -f "$TMP_FILE" "$ERR_FILE"' EXIT
install -d -m 700 "$STATE_DIR" /run/ir-stack
exec 9>"$LOCK_FILE"
flock -n 9 || exit 0
HOST="$(ir_host)"

journal_cmd=(journalctl _COMM=sshd -o short-iso --show-cursor)

write_cursor_from_file() {
    local src="$1" cursor tmp
    cursor="$(sed -n 's/^-- cursor: //p' "$src" | tail -n 1)"
    [[ -n "$cursor" ]] || return 1
    tmp="$STATE_FILE.tmp.$$"
    printf '%s\n' "$cursor" > "$tmp"
    chmod 600 "$tmp"
    mv -f "$tmp" "$STATE_FILE"
}

initialize_cursor() {
    local init
    init="$(mktemp)"
    if "${journal_cmd[@]}" -n 1 > "$init" 2>/dev/null; then
        write_cursor_from_file "$init" || true
    fi
    rm -f "$init"
}

if [[ ! -s "$STATE_FILE" ]]; then
    initialize_cursor
    exit 0
fi

if ! "${journal_cmd[@]}" --after-cursor "$(cat "$STATE_FILE")" > "$TMP_FILE" 2>"$ERR_FILE"; then
    msg="Cursor journald SSH non più valido o journal non leggibile. Stato reinizializzato; verificare possibile gap eventi. $(tr '\n' ' ' < "$ERR_FILE")"
    ir_log ssh-login-alert "$msg"
    ir_send_mail "[IR WARNING] SSH journal cursor reset su $HOST" "$msg" || true
    initialize_cursor
    exit 1
fi

while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    METHOD="$(sed -n 's/.*Accepted \([^ ]*\).*/\1/p' <<<"$line")"
    USERNAME="$(sed -n 's/.* for \([^ ]*\) from .*/\1/p' <<<"$line")"
    IPADDR="$(sed -n 's/.* from \([^ ]*\) port .*/\1/p' <<<"$line")"
    [[ -n "$USERNAME" && -n "$IPADDR" ]] || { ir_log ssh-login-alert "riga Accepted non parsabile: $line"; continue; }
    ir_log ssh-login-alert "login riuscito user=$USERNAME method=$METHOD ip=$IPADDR"
    printf -v BODY 'Host: %s\nUtente: %s\nIP: %s\nMetodo: %s\n\n%s' "$HOST" "$USERNAME" "$IPADDR" "$METHOD" "$line"
    ir_send_mail "[SSH LOGIN] $HOST user=$USERNAME ip=$IPADDR" "$BODY" || true
done < <(grep -E 'Accepted (publickey|password|keyboard-interactive|keyboard-interactive/pam)' "$TMP_FILE" || true)

write_cursor_from_file "$TMP_FILE" || true
