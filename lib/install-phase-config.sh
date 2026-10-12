# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Dascos
# Capture environment values so precedence can be:
# built-in defaults < installed config < --config file < environment < CLI.
ENV_ALERT_EMAIL="${ALERT_EMAIL-__IR_UNSET__}"
ENV_MAIL_MODE="${MAIL_MODE-__IR_UNSET__}"
ENV_RELAY_HOST="${RELAY_HOST-__IR_UNSET__}"
ENV_RELAY_PORT="${RELAY_PORT-__IR_UNSET__}"
ENV_RELAY_TLS="${RELAY_TLS-__IR_UNSET__}"
ENV_RELAY_TLS_MODE="${RELAY_TLS_MODE-__IR_UNSET__}"
ENV_RELAY_AUTH="${RELAY_AUTH-__IR_UNSET__}"
ENV_RELAY_USER="${RELAY_USER-__IR_UNSET__}"
ENV_RELAY_PASSWORD="${RELAY_PASSWORD-__IR_UNSET__}"
ENV_TRUSTED_SOURCES="${TRUSTED_SOURCES-__IR_UNSET__}"
ENV_TRUSTED_IPV4="${TRUSTED_IPV4-__IR_UNSET__}"
ENV_TRUSTED_IPV6="${TRUSTED_IPV6-__IR_UNSET__}"
ENV_FIREWALL_BACKEND="${FIREWALL_BACKEND-__IR_UNSET__}"
ENV_LOCKDOWN_KEEP_ESTABLISHED="${LOCKDOWN_KEEP_ESTABLISHED-__IR_UNSET__}"
ENV_BAN_BACKENDS="${BAN_BACKENDS-__IR_UNSET__}"
ENV_FAIL2BAN_INTEGRATION="${FAIL2BAN_INTEGRATION-__IR_UNSET__}"
ENV_OPENWRT_REMOTE_ENABLE="${OPENWRT_REMOTE_ENABLE-__IR_UNSET__}"
ENV_OPENWRT_HOST="${OPENWRT_HOST-__IR_UNSET__}"
ENV_OPENWRT_PORT="${OPENWRT_PORT-__IR_UNSET__}"
ENV_OPENWRT_USER="${OPENWRT_USER-__IR_UNSET__}"
ENV_OPENWRT_IDENTITY_FILE="${OPENWRT_IDENTITY_FILE-__IR_UNSET__}"
ENV_OPENWRT_KNOWN_HOSTS="${OPENWRT_KNOWN_HOSTS-__IR_UNSET__}"
ENV_SSH_PORT="${SSH_PORT-__IR_UNSET__}"
ENV_ENABLE_LOCKDOWN="${ENABLE_LOCKDOWN-__IR_UNSET__}"
ENV_HARDEN_SSH_LOGGING="${HARDEN_SSH_LOGGING-__IR_UNSET__}"
ENV_IDENTITY_SHELL_WHITELIST="${IDENTITY_SHELL_WHITELIST-__IR_UNSET__}"

NON_INTERACTIVE=no
CONFIG_FILE=""
ALERT_EMAIL=""
MAIL_MODE=""
RELAY_HOST=""
RELAY_PORT="25"
RELAY_TLS=""
RELAY_TLS_MODE=""
RELAY_AUTH="no"
RELAY_USER=""
RELAY_PASSWORD=""
RELAY_PASSWORD_FILE=""
TRUSTED_SOURCES=""
TRUSTED_IPV4=""
TRUSTED_IPV6=""
FIREWALL_BACKEND="auto"
LOCKDOWN_KEEP_ESTABLISHED="no"
BAN_BACKENDS="local"
FAIL2BAN_INTEGRATION="no"
OPENWRT_REMOTE_ENABLE="no"
OPENWRT_HOST=""
OPENWRT_PORT="22"
OPENWRT_USER="root"
OPENWRT_IDENTITY_FILE="/etc/ir-stack/openwrt_ed25519"
OPENWRT_KNOWN_HOSTS="/etc/ir-stack/openwrt_known_hosts"
SSH_PORT=""
ENABLE_LOCKDOWN="no"
HARDEN_SSH_LOGGING="yes"
IDENTITY_SHELL_WHITELIST=""

usage() { cat <<'EOF'
Uso: ./install.sh [opzioni]
  --config FILE
  --non-interactive
  --alert-email EMAIL
  --mail-mode existing|postfix-relay|none
  --relay-host HOST --relay-port PORT
  --relay-auth yes|no --relay-user USER [--relay-password-file FILE]
  --relay-tls-mode verify|encrypt|may|none
  --trusted-source IP_OR_CIDR   (ripetibile)
  --trusted-sources LIST        (comma/spazio)
  --trusted-ipv4 IP --trusted-ipv6 IP   (compatibilità)
  --firewall-backend auto|nftables|iptables|firewalld|none
  --lockdown-keep-established yes|no
  --ban-backends local|openwrt|local,openwrt
  --fail2ban-integration yes|no
  --openwrt-host HOST [--openwrt-port 22 --openwrt-user root]
  --openwrt-identity FILE --openwrt-known-hosts FILE
  --ssh-port PORT
  --enable-lockdown yes|no
  --whitelist-users user1,user2
EOF
}

args=("$@")
idx=0
while (( idx < ${#args[@]} )); do
    case "${args[$idx]}" in
        --config) CONFIG_FILE="${args[$((idx+1))]:-}"; idx=$((idx+2));;
        --non-interactive) NON_INTERACTIVE=yes; idx=$((idx+1));;
        *) idx=$((idx+1));;
    esac
done

if [[ -r /etc/ir-stack/ir-stack.conf ]]; then ir_load_config_file /etc/ir-stack/ir-stack.conf; fi
if [[ -n "$CONFIG_FILE" ]]; then
    [[ -r "$CONFIG_FILE" ]] || die "Config non leggibile: $CONFIG_FILE"
    ir_load_config_file "$CONFIG_FILE"
fi

for name in ALERT_EMAIL MAIL_MODE RELAY_HOST RELAY_PORT RELAY_TLS RELAY_TLS_MODE RELAY_AUTH RELAY_USER RELAY_PASSWORD TRUSTED_SOURCES TRUSTED_IPV4 TRUSTED_IPV6 FIREWALL_BACKEND LOCKDOWN_KEEP_ESTABLISHED BAN_BACKENDS FAIL2BAN_INTEGRATION OPENWRT_REMOTE_ENABLE OPENWRT_HOST OPENWRT_PORT OPENWRT_USER OPENWRT_IDENTITY_FILE OPENWRT_KNOWN_HOSTS SSH_PORT ENABLE_LOCKDOWN HARDEN_SSH_LOGGING IDENTITY_SHELL_WHITELIST; do
    env_name="ENV_${name}"
    if [[ "${!env_name}" != __IR_UNSET__ ]]; then printf -v "$name" '%s' "${!env_name}"; fi
done

set -- "${args[@]}"
while (($#)); do
    case "$1" in
        --config) shift 2;; --non-interactive) NON_INTERACTIVE=yes; shift;;
        --alert-email) ALERT_EMAIL="$2"; shift 2;; --mail-mode) MAIL_MODE="$2"; shift 2;;
        --relay-host) RELAY_HOST="$2"; shift 2;; --relay-port) RELAY_PORT="$2"; shift 2;;
        --relay-auth) RELAY_AUTH="${2:?--relay-auth richiede un valore}"; shift 2;;
        --relay-user) RELAY_USER="${2:?--relay-user richiede un valore}"; shift 2;;
        --relay-password) warn "--relay-password può finire nella history/process list; preferisci --relay-password-file o prompt interattivo"; RELAY_PASSWORD="${2:?--relay-password richiede un valore}"; shift 2;;
        --relay-password-file) RELAY_PASSWORD_FILE="${2:?--relay-password-file richiede un file}"; shift 2;;
        --relay-tls-mode) RELAY_TLS_MODE="${2:?--relay-tls-mode richiede un valore}"; shift 2;;
        --trusted-source) TRUSTED_SOURCES="${TRUSTED_SOURCES}${TRUSTED_SOURCES:+,}$2"; shift 2;;
        --trusted-sources) TRUSTED_SOURCES="$2"; shift 2;;
        --trusted-ipv4) TRUSTED_IPV4="$2"; TRUSTED_SOURCES="${TRUSTED_SOURCES}${TRUSTED_SOURCES:+,}$2"; shift 2;;
        --trusted-ipv6) TRUSTED_IPV6="$2"; TRUSTED_SOURCES="${TRUSTED_SOURCES}${TRUSTED_SOURCES:+,}$2"; shift 2;;
        --firewall-backend) FIREWALL_BACKEND="${2:?--firewall-backend richiede un valore}"; shift 2;;
        --lockdown-keep-established) LOCKDOWN_KEEP_ESTABLISHED="${2:?--lockdown-keep-established richiede un valore}"; shift 2;;
        --ban-backends) BAN_BACKENDS="$2"; shift 2;; --fail2ban-integration) FAIL2BAN_INTEGRATION="$2"; shift 2;;
        --openwrt-host) OPENWRT_HOST="$2"; OPENWRT_REMOTE_ENABLE=yes; shift 2;; --openwrt-port) OPENWRT_PORT="$2"; shift 2;;
        --openwrt-user) OPENWRT_USER="$2"; shift 2;; --openwrt-identity) OPENWRT_IDENTITY_FILE="$2"; shift 2;;
        --openwrt-known-hosts) OPENWRT_KNOWN_HOSTS="$2"; shift 2;; --ssh-port) SSH_PORT="$2"; shift 2;;
        --enable-lockdown) ENABLE_LOCKDOWN="$2"; shift 2;; --whitelist-users) IDENTITY_SHELL_WHITELIST="$2"; shift 2;;
        -h|--help) usage; exit 0;; *) die "Opzione sconosciuta: $1";;
    esac
done

require_root; require_systemd; require_apt
if [[ -z "$SSH_PORT" ]]; then SSH_PORT="$(sshd -T 2>/dev/null | awk '$1=="port"{print $2; exit}' || true)"; SSH_PORT="${SSH_PORT:-22}"; fi
if [[ -z "$TRUSTED_SOURCES" ]]; then TRUSTED_SOURCES="${TRUSTED_IPV4:-}${TRUSTED_IPV4:+,}${TRUSTED_IPV6:-}"; fi
if [[ -z "$IDENTITY_SHELL_WHITELIST" && -s /etc/ir-stack/identity-shell-whitelist ]]; then IDENTITY_SHELL_WHITELIST="$(paste -sd, /etc/ir-stack/identity-shell-whitelist)"; fi

if [[ "$NON_INTERACTIVE" != yes ]]; then
    echo "IR Stack installer $(cat "$ROOT_DIR/VERSION")"; echo
    ask ALERT_EMAIL "Email alert (vuota = niente email)" "$ALERT_EMAIL"
    if [[ -z "$ALERT_EMAIL" ]]; then MAIL_MODE=none; else ask MAIL_MODE "Modalità mail: existing, postfix-relay, none" "${MAIL_MODE:-existing}"; fi
    if [[ "$MAIL_MODE" == postfix-relay ]]; then
        ask RELAY_HOST "Relay SMTP" "$RELAY_HOST"; ask RELAY_PORT "Porta relay" "$RELAY_PORT"; ask RELAY_TLS_MODE "TLS relay: verify, encrypt, may, none" "${RELAY_TLS_MODE:-verify}"
        if yesno "Relay richiede autenticazione SMTP?" "$RELAY_AUTH"; then RELAY_AUTH=yes; ask RELAY_USER "Utente SMTP" "$RELAY_USER"; ask RELAY_PASSWORD "Password SMTP" "$RELAY_PASSWORD" yes; else RELAY_AUTH=no; fi
    fi
    ask SSH_PORT "Porta SSH" "$SSH_PORT"; ask TRUSTED_SOURCES "Trusted IP/reti CIDR (virgola: 192.168.2.43,10.0.10.0/24)" "$TRUSTED_SOURCES"; ask FIREWALL_BACKEND "Backend firewall: auto, nftables, iptables, firewalld, none" "$FIREWALL_BACKEND"
    if yesno "Durante lockdown preservare connessioni ESTABLISHED già aperte?" "$LOCKDOWN_KEEP_ESTABLISHED"; then LOCKDOWN_KEEP_ESTABLISHED=yes; else LOCKDOWN_KEEP_ESTABLISHED=no; fi
    if yesno "Abilitare lockdown automatico? ATTENZIONE: richiede test da console" "$ENABLE_LOCKDOWN"; then ENABLE_LOCKDOWN=yes; else ENABLE_LOCKDOWN=no; fi
    if yesno "Installare integrazione Fail2Ban (nessuna jail viene abilitata automaticamente)?" "$FAIL2BAN_INTEGRATION"; then FAIL2BAN_INTEGRATION=yes; ask BAN_BACKENDS "Backend ban: local, openwrt, local,openwrt" "$BAN_BACKENDS"; else FAIL2BAN_INTEGRATION=no; fi
    if [[ "$BAN_BACKENDS" == *openwrt* ]]; then
        OPENWRT_REMOTE_ENABLE=yes; ask OPENWRT_HOST "Host/IP OpenWrt remoto" "$OPENWRT_HOST"; ask OPENWRT_PORT "Porta SSH OpenWrt" "$OPENWRT_PORT"; ask OPENWRT_USER "Utente SSH OpenWrt" "$OPENWRT_USER"; ask OPENWRT_IDENTITY_FILE "Chiave privata dedicata OpenWrt" "$OPENWRT_IDENTITY_FILE"; ask OPENWRT_KNOWN_HOSTS "known_hosts dedicato OpenWrt" "$OPENWRT_KNOWN_HOSTS"
    fi
    default_wl="$IDENTITY_SHELL_WHITELIST"; if [[ -z "$default_wl" ]] && getent passwd asterisk >/dev/null 2>&1; then default_wl=asterisk; fi
    ask IDENTITY_SHELL_WHITELIST "Account di servizio con shell interattiva da whitelista (separati da virgola)" "$default_wl"
    if yesno "Impostare LogLevel VERBOSE in sshd_config?" "$HARDEN_SSH_LOGGING"; then HARDEN_SSH_LOGGING=yes; else HARDEN_SSH_LOGGING=no; fi
fi

if [[ -z "$MAIL_MODE" ]]; then [[ -n "$ALERT_EMAIL" ]] && MAIL_MODE=existing || MAIL_MODE=none; fi
if [[ -z "$RELAY_TLS_MODE" ]]; then case "${RELAY_TLS:-}" in yes) RELAY_TLS_MODE=may;; no) RELAY_TLS_MODE=none;; *) RELAY_TLS_MODE=verify;; esac; fi
if [[ -n "$RELAY_PASSWORD_FILE" ]]; then [[ -r "$RELAY_PASSWORD_FILE" ]] || die "Password file relay non leggibile: $RELAY_PASSWORD_FILE"; IFS= read -r RELAY_PASSWORD < "$RELAY_PASSWORD_FILE" || true; fi

if [[ "$FIREWALL_BACKEND" == auto ]]; then
    if command -v firewall-cmd >/dev/null 2>&1 && systemctl is-active --quiet firewalld 2>/dev/null; then FIREWALL_BACKEND=firewalld
    elif command -v nft >/dev/null 2>&1 && [[ -n "$(nft list ruleset 2>/dev/null | tr -d '[:space:]')" ]]; then FIREWALL_BACKEND=nftables
    elif command -v iptables >/dev/null 2>&1; then FIREWALL_BACKEND=iptables; else FIREWALL_BACKEND=nftables; fi
    say "Backend firewall auto risolto in: $FIREWALL_BACKEND"
fi
case "$MAIL_MODE" in existing|postfix-relay|none) ;; *) die "MAIL_MODE non valido: $MAIL_MODE";; esac
case "$RELAY_TLS_MODE" in verify|encrypt|may|none) ;; *) die "RELAY_TLS_MODE non valido: $RELAY_TLS_MODE";; esac
[[ "$RELAY_AUTH" =~ ^(yes|no)$ ]] || die "RELAY_AUTH deve essere yes/no"
[[ "$LOCKDOWN_KEEP_ESTABLISHED" =~ ^(yes|no)$ ]] || die "LOCKDOWN_KEEP_ESTABLISHED deve essere yes/no"
[[ "$ENABLE_LOCKDOWN" =~ ^(yes|no)$ ]] || die "ENABLE_LOCKDOWN deve essere yes/no"
[[ "$FAIL2BAN_INTEGRATION" =~ ^(yes|no)$ ]] || die "FAIL2BAN_INTEGRATION deve essere yes/no"
[[ "$OPENWRT_REMOTE_ENABLE" =~ ^(yes|no)$ ]] || die "OPENWRT_REMOTE_ENABLE deve essere yes/no"
[[ "$HARDEN_SSH_LOGGING" =~ ^(yes|no)$ ]] || die "HARDEN_SSH_LOGGING deve essere yes/no"
[[ "$SSH_PORT" =~ ^[0-9]+$ ]] && (( SSH_PORT>0 && SSH_PORT<65536 )) || die "SSH_PORT non valida"
[[ "$RELAY_PORT" =~ ^[0-9]+$ ]] && (( RELAY_PORT>0 && RELAY_PORT<65536 )) || die "RELAY_PORT non valida"
[[ "$OPENWRT_PORT" =~ ^[0-9]+$ ]] && (( OPENWRT_PORT>0 && OPENWRT_PORT<65536 )) || die "OPENWRT_PORT non valida"
case "$FIREWALL_BACKEND" in nftables|iptables|firewalld|none) ;; *) die "FIREWALL_BACKEND non valido: $FIREWALL_BACKEND";; esac
[[ -n "$BAN_BACKENDS" ]] || die "BAN_BACKENDS non può essere vuoto"
IFS=', ' read -ra _ban_check <<< "$BAN_BACKENDS"; for _b in "${_ban_check[@]}"; do [[ -z "$_b" || "$_b" == local || "$_b" == openwrt ]] || die "BAN_BACKENDS non valido: $_b"; done
for _v in "$ALERT_EMAIL" "$RELAY_HOST" "$RELAY_USER" "$OPENWRT_HOST" "$OPENWRT_USER" "$OPENWRT_IDENTITY_FILE" "$OPENWRT_KNOWN_HOSTS"; do [[ "$_v" != *$'\n'* && "$_v" != *$'\r'* ]] || die "Valore di configurazione contiene newline/control character"; done
if [[ -n "$ALERT_EMAIL" ]]; then [[ "$ALERT_EMAIL" != *[[:space:]]* && "$ALERT_EMAIL" == *@* ]] || die "ALERT_EMAIL non valida"; fi
case "$TRUSTED_SOURCES" in *[!0-9A-Fa-f:.,/\;[:space:]]*) die "TRUSTED_SOURCES contiene caratteri non ammessi";; esac
if [[ "$MAIL_MODE" == postfix-relay && "$RELAY_AUTH" == yes && "$RELAY_TLS_MODE" =~ ^(may|none)$ ]]; then die "Relay autenticato richiede TLS obbligatorio: usa RELAY_TLS_MODE=verify oppure encrypt"; fi
if [[ "$ENABLE_LOCKDOWN" == yes && -z "$TRUSTED_SOURCES" ]]; then die "Lockdown abilitato ma TRUSTED_SOURCES vuoto"; fi
if [[ "$BAN_BACKENDS" == *openwrt* ]]; then [[ -n "$OPENWRT_HOST" ]] || die "BAN_BACKENDS include openwrt ma OPENWRT_HOST è vuoto"; [[ -r "$OPENWRT_IDENTITY_FILE" && -r "$OPENWRT_KNOWN_HOSTS" ]] || die "Integrazione OpenWrt richiede chiave e known_hosts. Esegui scripts/bootstrap-openwrt.sh prima dell'installazione."; OPENWRT_REMOTE_ENABLE=yes; fi
if [[ "$MAIL_MODE" == postfix-relay && -z "$RELAY_HOST" ]]; then die "postfix-relay richiede RELAY_HOST"; fi
if [[ "$ENABLE_LOCKDOWN" == yes && "$NON_INTERACTIVE" != yes ]]; then echo; warn "Il lockdown può interrompere l'accesso remoto. Deve esistere un accesso console/out-of-band."; read -r -p 'Scrivi ENABLE per confermare: ' c; [[ "$c" == ENABLE ]] || die "Lockdown non confermato"; fi
