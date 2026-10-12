# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Dascos
say "Installo file IR Stack..."
install -d -m 700 /etc/ir-stack /var/lib/ir-stack /run/ir-stack /root/firewall-backups
install -d -m 755 /usr/local/lib/ir-stack /usr/local/lib/ir-stack/firewall /usr/local/share/ir-stack
install -m 755 "$ROOT_DIR/src/lib/common.sh" /usr/local/lib/ir-stack/common.sh
for f in "$ROOT_DIR"/src/firewall/*.sh; do install -m 700 "$f" "/usr/local/lib/ir-stack/firewall/$(basename "$f")"; done
for f in "$ROOT_DIR"/src/bin/*; do install -m 700 "$f" "/usr/local/sbin/$(basename "$f")"; done
install -m 644 "$ROOT_DIR/VERSION" /usr/local/share/ir-stack/VERSION

{
    ir_config_line ALERT_EMAIL "$ALERT_EMAIL"
    ir_config_line MAIL_MODE "$MAIL_MODE"
    ir_config_line RELAY_HOST "$RELAY_HOST"
    ir_config_line RELAY_PORT "$RELAY_PORT"
    ir_config_line RELAY_TLS_MODE "$RELAY_TLS_MODE"
    ir_config_line RELAY_AUTH "$RELAY_AUTH"
    ir_config_line RELAY_USER "$RELAY_USER"
    ir_config_line TRUSTED_SOURCES "$TRUSTED_SOURCES"
    ir_config_line FIREWALL_BACKEND "$FIREWALL_BACKEND"
    ir_config_line LOCKDOWN_KEEP_ESTABLISHED "$LOCKDOWN_KEEP_ESTABLISHED"
    ir_config_line BAN_BACKENDS "$BAN_BACKENDS"
    ir_config_line FAIL2BAN_INTEGRATION "$FAIL2BAN_INTEGRATION"
    ir_config_line OPENWRT_REMOTE_ENABLE "$OPENWRT_REMOTE_ENABLE"
    ir_config_line OPENWRT_HOST "$OPENWRT_HOST"
    ir_config_line OPENWRT_PORT "$OPENWRT_PORT"
    ir_config_line OPENWRT_USER "$OPENWRT_USER"
    ir_config_line OPENWRT_IDENTITY_FILE "$OPENWRT_IDENTITY_FILE"
    ir_config_line OPENWRT_KNOWN_HOSTS "$OPENWRT_KNOWN_HOSTS"
    ir_config_line SSH_PORT "$SSH_PORT"
    ir_config_line ENABLE_LOCKDOWN "$ENABLE_LOCKDOWN"
} > /etc/ir-stack/ir-stack.conf
chmod 600 /etc/ir-stack/ir-stack.conf
: > /etc/ir-stack/identity-shell-whitelist
IFS=',' read -ra users <<< "$IDENTITY_SHELL_WHITELIST"
for u in "${users[@]}"; do u="${u//[[:space:]]/}"; [[ -n "$u" ]] && echo "$u" >> /etc/ir-stack/identity-shell-whitelist; done
chmod 600 /etc/ir-stack/identity-shell-whitelist

install -m 600 "$ROOT_DIR/src/audit/41-ir-stack-self.rules" /etc/audit/rules.d/41-ir-stack-self.rules
if [[ ! -s /var/lib/ir-stack/ssh-keys.baseline ]]; then
    /usr/local/sbin/accept-ssh-key-baseline.sh
else
    say "Baseline authorized_keys esistente mantenuta; usare irctl ssh-baseline-accept solo dopo verifica esplicita."
fi

for f in "$ROOT_DIR"/src/systemd/*; do install -m 644 "$f" "/etc/systemd/system/$(basename "$f")"; done
if [[ "$FAIL2BAN_INTEGRATION" == yes ]]; then
    install -d -m 755 /etc/fail2ban/action.d
    install -m 644 "$ROOT_DIR/integrations/fail2ban/action.d/ir-stack.conf" /etc/fail2ban/action.d/ir-stack.conf
    systemctl enable --now fail2ban || true
fi

if [[ "$HARDEN_SSH_LOGGING" == yes && -f /etc/ssh/sshd_config ]]; then
    if grep -qE '^[#[:space:]]*LogLevel[[:space:]]+' /etc/ssh/sshd_config; then
        sed -i 's/^[#[:space:]]*LogLevel[[:space:]].*/LogLevel VERBOSE/' /etc/ssh/sshd_config
    else echo 'LogLevel VERBOSE' >> /etc/ssh/sshd_config; fi
    if ! sshd -t; then
        if [[ -f "$backup/sshd_config" ]]; then cp -a "$backup/sshd_config" /etc/ssh/sshd_config; fi
        die "sshd_config non valida dopo LogLevel VERBOSE: ripristinata la copia precedente"
    fi
    systemctl reload ssh 2>/dev/null || systemctl reload sshd 2>/dev/null || true
fi

cat > /etc/profile.d/irctl.sh <<'EOF'
alias ir='/usr/local/sbin/irctl'
EOF
chmod 644 /etc/profile.d/irctl.sh

systemctl enable --now auditd
set +e
/usr/local/sbin/refresh-audit-rules.sh
audit_rc=$?
set -e
if (( audit_rc != 0 && audit_rc != 10 )); then
    die "Caricamento regole audit fallito (rc=$audit_rc)"
fi
if (( audit_rc == 10 )); then
    warn "auditd immutable: regole salvate ma non attive fino al reboot"
fi
systemctl daemon-reload
systemctl enable --now ir-stack-identity.path ir-stack-identity.timer ir-stack-ssh-login.timer ir-stack-self-watch.path ir-stack-guardians.timer

/usr/local/sbin/check-identity-anomalies.sh || true
systemctl start ir-stack-ssh-login.service || true
systemctl start ir-stack-guardians.service || true

cleanup_install_maintenance
INSTALL_MAINTENANCE_CREATED=no
trap - EXIT

echo
say "Installazione completata. Backup pre-modifica: $backup"
echo "Config: /etc/ir-stack/ir-stack.conf"
echo "Controllo: irctl doctor"
echo "Test mail: irctl mail-test"
echo "Stato: irctl status"
