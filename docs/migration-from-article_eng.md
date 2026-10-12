# Migration from the article baseline

[Italiano](migration-from-article.md) | **English**

The baseline published in the article uses:

- `/etc/incident-response/lockdown.conf`;
- `/etc/incident-response/identity-shell-whitelist`;
- units named `identity-*`, `ssh-login-alert.*`, `ir-stack-watch.*`, `ir-guardians-watchdog.*`;
- an SSH trigger based on `/var/log/auth.log`;
- a hardcoded `asterisk` whitelist entry;
- a trusted IPv4 address required during installation;
- configuration generated as a shell fragment.

The repository version instead installs under `/etc/ir-stack`, uses `ir-stack-*`-prefixed units, non-executable `KEY=VALUE` configuration, multiple trusted sources, dynamic audit rules, and an `authorized_keys` baseline.

For a machine already running the article baseline, the recommended migration is:

1. back up `/etc/incident-response`, audit rules, and systemd units;
2. verify and record email settings, trusted sources, SSH port, and whitelist entries;
3. disable the old units without immediately removing files and logs;
4. install the new version;
5. run `irctl doctor`, `irctl check`, and `irctl mail-test`;
6. inspect `irctl ssh-baseline-show` and accept the baseline only if the existing keys are expected;
7. verify `auditctl -s` and `irctl audit`; if auditd is immutable, a reboot may be required;
8. manually test any lockdown + rollback from console access;
9. remove the old files only after all checks pass.

rc1 does not automatically migrate customizations from the article baseline: automatically interpreting historical root-level configuration would be riskier than requiring an explicit migration.
