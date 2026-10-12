#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Dascos
set -euo pipefail
. /usr/local/lib/ir-stack/common.sh
ir_load_config
cmd="${1:-}"; arg="${2:-}"
LOCK_POLICY=ir-lockdown
BAN_POLICY=ir-ban
need() {
    if ! command -v firewall-cmd >/dev/null 2>&1 || ! systemctl is-active --quiet firewalld; then
        echo 'firewalld non attivo' >&2
        exit 2
    fi
}
rich_ssh(){ local family="$1" src="$2"; printf 'rule family="%s" source address="%s" port port="%s" protocol="tcp" accept' "$family" "$src" "$SSH_PORT"; }
policy_exists(){ firewall-cmd --get-policies | tr ' ' '\n' | grep -qx "$1"; }
lock_apply(){
    need
    if policy_exists "$LOCK_POLICY"; then echo 'policy lockdown già presente' >&2; return 1; fi
    if ! {
        firewall-cmd --new-policy="$LOCK_POLICY" >/dev/null
        firewall-cmd --policy="$LOCK_POLICY" --add-ingress-zone=ANY >/dev/null
        firewall-cmd --policy="$LOCK_POLICY" --add-egress-zone=HOST >/dev/null
        firewall-cmd --policy="$LOCK_POLICY" --set-priority=-32760 >/dev/null
        while read -r src; do [[ -n "$src" ]] && firewall-cmd --policy="$LOCK_POLICY" --add-rich-rule="$(rich_ssh ipv4 "$src")" >/dev/null; done < <(ir_normalize_sources "$TRUSTED_SOURCES" 4)
        while read -r src; do [[ -n "$src" ]] && firewall-cmd --policy="$LOCK_POLICY" --add-rich-rule="$(rich_ssh ipv6 "$src")" >/dev/null; done < <(ir_normalize_sources "$TRUSTED_SOURCES" 6)
        firewall-cmd --policy="$LOCK_POLICY" --set-target=DROP >/dev/null
    }; then
        firewall-cmd --delete-policy="$LOCK_POLICY" >/dev/null 2>&1 || true
        return 1
    fi
}
lock_rollback(){ need; firewall-cmd --delete-policy="$LOCK_POLICY" >/dev/null 2>&1 || true; }
lock_status(){ need; firewall-cmd --policy="$LOCK_POLICY" --list-all; }
ban_ensure(){
    need
    if policy_exists "$BAN_POLICY"; then return 0; fi
    if ! {
        firewall-cmd --new-policy="$BAN_POLICY" >/dev/null
        firewall-cmd --policy="$BAN_POLICY" --add-ingress-zone=ANY >/dev/null
        firewall-cmd --policy="$BAN_POLICY" --add-egress-zone=HOST >/dev/null
        firewall-cmd --policy="$BAN_POLICY" --set-priority=-32750 >/dev/null
        firewall-cmd --policy="$BAN_POLICY" --set-target=CONTINUE >/dev/null
    }; then
        firewall-cmd --delete-policy="$BAN_POLICY" >/dev/null 2>&1 || true
        return 1
    fi
}
ban_rule(){ local ip="$1" fam=ipv4; [[ "$ip" == *:* ]] && fam=ipv6; printf 'rule family="%s" source address="%s" drop' "$fam" "$ip"; }
ban_add(){ local ip rule; ip="$(ir_validate_ip "$1")"; rule="$(ban_rule "$ip")"; ban_ensure; firewall-cmd --policy="$BAN_POLICY" --query-rich-rule="$rule" >/dev/null 2>&1 || firewall-cmd --policy="$BAN_POLICY" --add-rich-rule="$rule" >/dev/null; }
ban_del(){ local ip rule; ip="$(ir_validate_ip "$1")"; rule="$(ban_rule "$ip")"; need; if ! policy_exists "$BAN_POLICY"; then return 0; fi; firewall-cmd --policy="$BAN_POLICY" --remove-rich-rule="$rule" >/dev/null 2>&1 || true; }
ban_status(){ need; if policy_exists "$BAN_POLICY"; then firewall-cmd --policy="$BAN_POLICY" --list-rich-rules; else echo 'nessuna policy ban IR Stack'; fi; }
ban_flush(){ need; firewall-cmd --delete-policy="$BAN_POLICY" >/dev/null 2>&1 || true; }
case "$cmd" in lockdown-apply) lock_apply;; lockdown-rollback) lock_rollback;; lockdown-status) lock_status;; ban-add) ban_add "$arg";; ban-del) ban_del "$arg";; ban-status) ban_status;; ban-flush) ban_flush;; check) need;; *) echo "Uso: $0 ..." >&2; exit 2;; esac
