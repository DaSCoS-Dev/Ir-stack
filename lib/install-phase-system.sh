# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Dascos
stamp="$(date +%Y%m%d-%H%M%S)"
backup="/var/backups/ir-stack/$stamp"
install -d -m 700 "$backup"
for p in /etc/ir-stack /etc/audit/rules.d/40-ir-stack-identity.rules /etc/audit/rules.d/41-ir-stack-self.rules /etc/audit/rules.d/42-ir-stack-sshkeys.rules /etc/ssh/sshd_config /etc/postfix/main.cf /etc/postfix/sasl_passwd /etc/postfix/sasl_passwd.db /etc/mailname; do
    [[ -e "$p" ]] && cp -a "$p" "$backup/" || true
done

install -d -m 700 /run/ir-stack
INSTALL_MAINTENANCE_CREATED=no
if [[ ! -e /run/ir-stack/maintenance.until ]]; then
    printf '%s\n' "$(( $(date +%s) + 1800 ))" > /run/ir-stack/maintenance.until
    chmod 600 /run/ir-stack/maintenance.until
    INSTALL_MAINTENANCE_CREATED=yes
fi
cleanup_install_maintenance() {
    [[ "$INSTALL_MAINTENANCE_CREATED" == yes ]] && rm -f /run/ir-stack/maintenance.until || true
}
install_exit_handler() {
    rc=$?
    trap - EXIT
    cleanup_install_maintenance
    if (( rc != 0 )); then
        printf 'failed_at=%s rc=%s\n' "$(date --iso-8601=seconds)" "$rc" > "$backup/INSTALL_FAILED" 2>/dev/null || true
        warn "Installazione interrotta (rc=$rc). Backup pre-modifica: $backup"
        warn "Non viene eseguito un rollback automatico completo delle configurazioni esterne: verificare Postfix/firewall/systemd prima di riprovare."
    fi
    exit "$rc"
}
trap install_exit_handler EXIT

say "Installo dipendenze base..."
export DEBIAN_FRONTEND=noninteractive
apt-get update
base_pkgs=(auditd audispd-plugins util-linux python3-minimal openssh-client)
case "$FIREWALL_BACKEND" in nftables) base_pkgs+=(nftables);; iptables) base_pkgs+=(iptables);; firewalld|none) :;; esac
if [[ "$FAIL2BAN_INTEGRATION" == yes ]]; then base_pkgs+=(fail2ban); fi
if [[ "$MAIL_MODE" == postfix-relay ]]; then
    base_pkgs+=(postfix bsd-mailx); [[ "$RELAY_AUTH" == yes ]] && base_pkgs+=(libsasl2-modules)
    fqdn_preseed="$(hostname -f 2>/dev/null || hostname)"
    {
        echo "postfix postfix/mailname string $fqdn_preseed"
        echo "postfix postfix/main_mailer_type select Satellite system"
        echo "postfix postfix/relayhost string [$RELAY_HOST]:$RELAY_PORT"
    } | debconf-set-selections
fi
apt-get install -y "${base_pkgs[@]}"
python3 -c "import ipaddress,re,sys; [ipaddress.ip_network(x, strict=False) for x in re.split(r'[\s,;]+', sys.argv[1].strip()) if x]" "$TRUSTED_SOURCES" || die "TRUSTED_SOURCES contiene IP/CIDR non validi"
if [[ "$ENABLE_LOCKDOWN" == yes ]]; then
    case "$FIREWALL_BACKEND" in
        firewalld) command -v firewall-cmd >/dev/null 2>&1 && systemctl is-active --quiet firewalld || die "FIREWALL_BACKEND=firewalld ma firewalld non è installato/attivo";;
        nftables) command -v nft >/dev/null 2>&1 || die "nft non disponibile";;
        iptables) command -v iptables >/dev/null 2>&1 || die "iptables non disponibile";;
        none) die "Lockdown abilitato con FIREWALL_BACKEND=none";;
    esac
fi

if [[ "$MAIL_MODE" == existing ]]; then
    command -v sendmail >/dev/null 2>&1 || command -v mail >/dev/null 2>&1 || warn "MAIL_MODE=existing ma non trovo sendmail/mail: irctl mail-test fallirà finché non configuri un MTA."
fi

if [[ "$MAIL_MODE" == postfix-relay ]]; then
    say "Configuro Postfix satellite..."
    fqdn="$(hostname -f 2>/dev/null || hostname)"
    printf '%s\n' "$fqdn" > /etc/mailname
    postconf -e "myhostname = $fqdn"
    postconf -e 'myorigin = /etc/mailname'
    postconf -e 'inet_interfaces = loopback-only'
    postconf -e 'mynetworks = 127.0.0.0/8 [::1]/128'
    postconf -e "relayhost = [$RELAY_HOST]:$RELAY_PORT"
    postconf -e 'mydestination = $myhostname, localhost.$mydomain, localhost, $myorigin'
    postconf -e "smtp_tls_security_level = $RELAY_TLS_MODE"
    if [[ "$RELAY_AUTH" == yes ]]; then
        [[ -n "$RELAY_USER" ]] || die "Relay auth richiesto ma RELAY_USER mancante"
        [[ "$RELAY_PASSWORD" != *$'\n'* && "$RELAY_PASSWORD" != *$'\r'* ]] || die "Password relay contiene newline"
        postconf -e 'smtp_sasl_auth_enable = yes'
        postconf -e 'smtp_sasl_security_options = noanonymous'
        postconf -e 'smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd'
        if [[ -n "$RELAY_PASSWORD" ]]; then
            umask 077
            printf '[%s]:%s %s:%s\n' "$RELAY_HOST" "$RELAY_PORT" "$RELAY_USER" "$RELAY_PASSWORD" > /etc/postfix/sasl_passwd
            postmap /etc/postfix/sasl_passwd
            chmod 600 /etc/postfix/sasl_passwd /etc/postfix/sasl_passwd.db
        elif [[ ! -s /etc/postfix/sasl_passwd.db ]]; then
            die "Relay auth richiesto: password non fornita e mappa SASL esistente assente"
        fi
    else
        postconf -e 'smtp_sasl_auth_enable = no'
    fi
    systemctl enable --now postfix
fi
