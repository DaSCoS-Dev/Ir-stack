#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Dascos
set -euo pipefail

IR_CONFIG="${IR_CONFIG:-/etc/ir-stack/ir-stack.conf}"
IR_RUN_DIR="${IR_RUN_DIR:-/run/ir-stack}"
IR_STATE_DIR="${IR_STATE_DIR:-/var/lib/ir-stack}"
IR_LOG_DIR="${IR_LOG_DIR:-/var/log}"

_ir_trim() {
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "$s"
}

_ir_config_key_allowed() {
    case "$1" in
        ALERT_EMAIL|MAIL_MODE|RELAY_HOST|RELAY_PORT|RELAY_TLS|RELAY_TLS_MODE|RELAY_AUTH|RELAY_USER|\
        TRUSTED_SOURCES|TRUSTED_IPV4|TRUSTED_IPV6|FIREWALL_BACKEND|LOCKDOWN_KEEP_ESTABLISHED|\
        BAN_BACKENDS|FAIL2BAN_INTEGRATION|OPENWRT_REMOTE_ENABLE|OPENWRT_HOST|OPENWRT_PORT|OPENWRT_USER|\
        OPENWRT_IDENTITY_FILE|OPENWRT_KNOWN_HOSTS|SSH_PORT|ENABLE_LOCKDOWN|HARDEN_SSH_LOGGING|\
        IDENTITY_SHELL_WHITELIST) return 0 ;;
        *) return 1 ;;
    esac
}

_ir_config_decode_value() {
    local v; v="$(_ir_trim "$1")"
    if [[ ${#v} -ge 2 && ${v:0:1} == '"' && ${v: -1} == '"' ]]; then
        v="${v:1:${#v}-2}"
        v="${v//\\\"/\"}"
        v="${v//\\\\/\\}"
    elif [[ ${#v} -ge 2 && ${v:0:1} == "'" && ${v: -1} == "'" ]]; then
        v="${v:1:${#v}-2}"
    fi
    [[ "$v" != *$'\n'* && "$v" != *$'\r'* ]] || return 2
    printf '%s' "$v"
}

_ir_load_config_file() {
    local file="$1" line key rhs value lineno=0
    [[ -r "$file" ]] || return 0
    while IFS= read -r line || [[ -n "$line" ]]; do
        lineno=$((lineno+1)); line="${line%$'\r'}"
        [[ "$line" =~ ^[[:space:]]*$ || "$line" =~ ^[[:space:]]*# ]] && continue
        if [[ "$line" =~ ^[[:space:]]*([A-Z][A-Z0-9_]*)[[:space:]]*=(.*)$ ]]; then
            key="${BASH_REMATCH[1]}"; rhs="${BASH_REMATCH[2]}"
        else
            echo "IR Stack: config $file:$lineno non valida" >&2; return 2
        fi
        _ir_config_key_allowed "$key" || { echo "IR Stack: chiave config non ammessa: $key" >&2; return 2; }
        value="$(_ir_config_decode_value "$rhs")" || { echo "IR Stack: valore config non valido per $key" >&2; return 2; }
        printf -v "$key" '%s' "$value"
    done < "$file"
}

ir_load_config() {
    _ir_load_config_file "$IR_CONFIG"
    ALERT_EMAIL="${ALERT_EMAIL:-}"
    MAIL_MODE="${MAIL_MODE:-none}"
    TRUSTED_SOURCES="${TRUSTED_SOURCES:-}"
    if [[ -z "$TRUSTED_SOURCES" ]]; then
        TRUSTED_SOURCES="${TRUSTED_IPV4:-}${TRUSTED_IPV4:+,}${TRUSTED_IPV6:-}"
    fi
    SSH_PORT="${SSH_PORT:-22}"
    ENABLE_LOCKDOWN="${ENABLE_LOCKDOWN:-no}"
    FIREWALL_BACKEND="${FIREWALL_BACKEND:-auto}"
    LOCKDOWN_KEEP_ESTABLISHED="${LOCKDOWN_KEEP_ESTABLISHED:-no}"
    BAN_BACKENDS="${BAN_BACKENDS:-local}"
    FAIL2BAN_INTEGRATION="${FAIL2BAN_INTEGRATION:-no}"
    OPENWRT_REMOTE_ENABLE="${OPENWRT_REMOTE_ENABLE:-no}"
    OPENWRT_HOST="${OPENWRT_HOST:-}"
    OPENWRT_PORT="${OPENWRT_PORT:-22}"
    OPENWRT_USER="${OPENWRT_USER:-root}"
    OPENWRT_IDENTITY_FILE="${OPENWRT_IDENTITY_FILE:-/etc/ir-stack/openwrt_ed25519}"
    OPENWRT_KNOWN_HOSTS="${OPENWRT_KNOWN_HOSTS:-/etc/ir-stack/openwrt_known_hosts}"
}

ir_host() {
    local host
    host="$(hostname -f 2>/dev/null || true)"
    case "$host" in ""|localhost|localhost.localdomain) hostname ;; *) printf '%s\n' "$host" ;; esac
}

ir_log() { local tag="$1"; shift; logger -t "$tag" -- "$*"; }
ir_maintenance_file() { printf '%s/maintenance.until\n' "$IR_RUN_DIR"; }

ir_maintenance_active() {
    local f now until
    f="$(ir_maintenance_file)"
    [[ -s "$f" ]] || return 1
    now="$(date +%s)"; until="$(cat "$f" 2>/dev/null || echo 0)"
    [[ "$until" =~ ^[0-9]+$ ]] || return 1
    if (( now < until )); then return 0; fi
    rm -f "$f" 2>/dev/null || true
    return 1
}

ir_send_mail() {
    local subject="$1" body="$2" rc=0
    ir_load_config
    [[ -n "$ALERT_EMAIL" && "$MAIL_MODE" != none ]] || return 0
    if ir_maintenance_active; then ir_log ir-stack "maintenance attiva: email soppressa subject=$subject"; return 0; fi
    subject="${subject//$'\r'/ }"; subject="${subject//$'\n'/ }"
    if [[ "$ALERT_EMAIL" == *$'\r'* || "$ALERT_EMAIL" == *$'\n'* ]]; then
        ir_log ir-stack "ALERT_EMAIL non valida: contiene newline"; return 2
    fi
    if command -v sendmail >/dev/null 2>&1; then
        { printf 'To: %s\nSubject: %s\nContent-Type: text/plain; charset=UTF-8\n\n%s\n' "$ALERT_EMAIL" "$subject" "$body"; } | sendmail -t || rc=$?
    elif command -v mail >/dev/null 2>&1; then
        printf '%s\n' "$body" | mail -s "$subject" "$ALERT_EMAIL" || rc=$?
    else
        ir_log ir-stack "mail command assente: impossibile inviare subject=$subject"; return 127
    fi
    (( rc == 0 )) || ir_log ir-stack "invio mail fallito rc=$rc subject=$subject"
    return "$rc"
}

ir_normalize_sources() {
    local raw="${1:-}" family="${2:-any}"
    python3 - "$raw" "$family" <<'PYNET'
import ipaddress,re,sys
raw,fam=sys.argv[1],sys.argv[2]
seen=set()
for token in re.split(r'[\s,;]+', raw.strip()):
    if not token: continue
    try: n=ipaddress.ip_network(token, strict=False)
    except ValueError as e:
        print(f"IR Stack: trusted source non valida: {token}: {e}", file=sys.stderr); sys.exit(2)
    if fam=='4' and n.version != 4: continue
    if fam=='6' and n.version != 6: continue
    s=str(n)
    if s not in seen: print(s); seen.add(s)
PYNET
}

ir_validate_sources() { ir_normalize_sources "${1:-}" any >/dev/null; }

ir_ip_is_trusted() {
    local ip="$1" raw="${2:-${TRUSTED_SOURCES:-}}"
    python3 - "$ip" "$raw" <<'PYNET'
import ipaddress,re,sys
try: ip=ipaddress.ip_address(sys.argv[1])
except ValueError: sys.exit(2)
for token in re.split(r'[\s,;]+', sys.argv[2].strip()):
    if not token: continue
    try: net=ipaddress.ip_network(token, strict=False)
    except ValueError: continue
    if ip.version == net.version and ip in net: sys.exit(0)
sys.exit(1)
PYNET
}

ir_validate_ip() {
    python3 - "$1" <<'PYNET'
import ipaddress,sys
try: print(ipaddress.ip_address(sys.argv[1]))
except ValueError: sys.exit(2)
PYNET
}

ir_detect_firewall_backend() {
    if command -v firewall-cmd >/dev/null 2>&1 && systemctl is-active --quiet firewalld 2>/dev/null; then echo firewalld; return; fi
    if command -v nft >/dev/null 2>&1; then echo nftables; return; fi
    if command -v iptables >/dev/null 2>&1; then echo iptables; return; fi
    echo none
}

ir_resolve_firewall_backend() {
    ir_load_config
    case "$FIREWALL_BACKEND" in
        auto) ir_detect_firewall_backend ;;
        nftables|iptables|firewalld|none) echo "$FIREWALL_BACKEND" ;;
        *) echo "Backend firewall non valido: $FIREWALL_BACKEND" >&2; return 2 ;;
    esac
}

ir_firewall_driver() {
    local backend="$1"
    local driver="/usr/local/lib/ir-stack/firewall/$backend.sh"
    [[ -x "$driver" ]] || { echo "Driver firewall assente: $driver" >&2; return 2; }
    printf '%s\n' "$driver"
}
