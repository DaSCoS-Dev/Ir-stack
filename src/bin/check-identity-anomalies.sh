#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Dascos
set -euo pipefail

PASSWD_FILE="/etc/passwd"
LOGIN_DEFS="/etc/login.defs"
SSHD_CFG="/etc/ssh/sshd_config"
LOCAL_WHITELIST="/etc/ir-stack/identity-shell-whitelist"

UID_MIN=$(awk '/^[[:space:]]*UID_MIN[[:space:]]+/ {print $2}' "$LOGIN_DEFS" 2>/dev/null | tail -n1)
SYS_UID_MIN=$(awk '/^[[:space:]]*SYS_UID_MIN[[:space:]]+/ {print $2}' "$LOGIN_DEFS" 2>/dev/null | tail -n1)
SYS_UID_MAX=$(awk '/^[[:space:]]*SYS_UID_MAX[[:space:]]+/ {print $2}' "$LOGIN_DEFS" 2>/dev/null | tail -n1)
UID_MIN="${UID_MIN:-1000}"
SYS_UID_MIN="${SYS_UID_MIN:-101}"
SYS_UID_MAX="${SYS_UID_MAX:-$((UID_MIN-1))}"
ALERT=0
HOST="$(hostname -f 2>/dev/null || hostname)"

is_interactive_shell() {
    local shell="${1:-}"
    [[ -n "$shell" ]] || return 1
    case "$shell" in */nologin|*/false) return 1 ;; esac
    [[ -r /etc/shells ]] && grep -qxF "$shell" /etc/shells
}

is_whitelisted_user() {
    local user="${1:-}"
    [[ -f "$LOCAL_WHITELIST" ]] || return 1
    grep -qxF "$user" "$LOCAL_WHITELIST"
}

printf '[%s] host=%s\n' "$(date --iso-8601=seconds)" "$HOST"
printf '== Account con UID 0 ==\n'
awk -F: '($3 == 0) {print}' "$PASSWD_FILE"
UID0_COUNT=$(awk -F: '($3 == 0) {c++} END {print c+0}' "$PASSWD_FILE")
if (( UID0_COUNT > 1 )); then echo "ALERT: trovati $UID0_COUNT account con UID 0"; ALERT=1; fi
if ! awk -F: '($1=="root" && $3==0) {found=1} END {exit !found}' "$PASSWD_FILE"; then echo "ALERT: account root mancante o con UID non 0"; ALERT=1; fi

echo
echo "== Account sotto UID_MIN con shell interattiva reale (escluso root) =="
while IFS=: read -r user _ uid gid gecos home shell; do
    [[ "$user" != root ]] || continue
    if (( uid < UID_MIN )) && ! is_whitelisted_user "$user" && is_interactive_shell "$shell"; then
        printf '%s:x:%s:%s:%s:%s:%s\n' "$user" "$uid" "$gid" "$gecos" "$home" "$shell"
        echo "ALERT: account '$user' sotto UID_MIN con shell interattiva reale ($shell)"
        ALERT=1
    fi
done < "$PASSWD_FILE"

echo
echo "== authorized_keys sensibili =="
while IFS= read -r -d '' f; do
    stat --printf '%n owner=%U group=%G mode=%a mtime=%y\n' "$f"
    mode=$(stat -c %a "$f"); mode_num=$((10#$mode)); group_digit=$(( (mode_num / 10) % 10 )); other_digit=$(( mode_num % 10 ))
    if (( (group_digit & 2) != 0 || (other_digit & 2) != 0 )); then echo "ALERT: authorized_keys scrivibile da group/other: $f mode=$mode"; ALERT=1; fi
done < <(find /root/.ssh /home -xdev -type f -name authorized_keys -print0 2>/dev/null || true)

echo
echo "== baseline authorized_keys =="
BASELINE="/var/lib/ir-stack/ssh-keys.baseline"
CURRENT="$(mktemp)"
trap 'rm -f "$CURRENT"' EXIT
/usr/local/sbin/ssh-key-inventory.sh > "$CURRENT"
if [[ -s "$BASELINE" ]]; then
    if ! cmp -s "$BASELINE" "$CURRENT"; then echo "ALERT: inventario authorized_keys diverso dalla baseline"; diff -u "$BASELINE" "$CURRENT" || true; ALERT=1; fi
else
    echo "ALERT: baseline authorized_keys assente; eseguire irctl ssh-baseline-accept"; ALERT=1
fi

echo
echo "== sshd_config =="
if [[ -f "$SSHD_CFG" ]]; then grep -Ei '^(PermitRootLogin|PasswordAuthentication|PubkeyAuthentication|AllowUsers|AllowGroups|Match|LogLevel)' "$SSHD_CFG" || true; fi
exit "$ALERT"
