# Changelog

## 0.2.0-rc1

Security/code review completa della `0.2.0-dev` e remediation pre-pubblicazione.

### Security

- i file config non vengono più eseguiti con `source`: parser `KEY=VALUE` con allowlist;
- uninstall esegue rollback/cleanup firewall prima di eliminare gli strumenti di recupero;
- host-key OpenWrt pinning su una sola chiave effettivamente verificata;
- audit rules generate dinamicamente per oggetti esistenti; errori `augenrules` non più nascosti;
- gestione esplicita audit immutable/reboot-required;
- `LOCKDOWN_KEEP_ESTABLISHED=no` come default di containment;
- cursor journald SSH aggiornato atomicamente e recupero esplicito da cursor invalido;
- baseline degli `authorized_keys` con accettazione manuale;
- SMTP autenticato richiede TLS `verify` o `encrypt`;
- password SMTP supportata via file per evitare esposizione in history/process list;
- validazione semantica degli IP sul helper OpenWrt;
- config-RCE regression test in CI.

### Firewall / runtime

- policy firewalld `ir-ban` da ANY a HOST per ban trasversali alle zone;
- apply/rollback più conservativi per i backend locali;
- `ban-flush` per pulizia mirata dello stato IR Stack;
- sandbox systemd irrigidito e path Postfix reso facoltativo;
- guardian separa auto-repair delle unità IR da alert-only di auditd/Postfix/Fail2Ban.

### Tooling

- `irctl ssh-baseline-show` e `irctl ssh-baseline-accept`;
- CI estesa a driver firewall, script POSIX OpenWrt e standalone installer;
- `persist-credentials: false` nel checkout GitHub Actions;
- `SECURITY-REVIEW.md` con finding, remediation e rischi residui.

## 0.2.0-dev

- GPL-3.0-or-later e copyright Dascos.
- `TRUSTED_SOURCES` multipla con IP e CIDR IPv4/IPv6.
- backend lockdown modulari nftables, iptables e firewalld senza flush globale.
- dispatcher `ir-ban` con backend locale/OpenWrt.
- integrazione OpenWrt remota con forced-command e fallback banIP/nftables fw4.
- action Fail2Ban opzionale.
- bootstrap OpenWrt con chiave Ed25519 e host-key pinning.

## 0.1.0

- refactor della baseline standalone pubblicata su SicurezzaReti;
- installer interattivo e unattended;
- mail mode existing / postfix-relay / none;
- maintenance window;
- SSH login polling via journald timer;
- audit dinamico degli `authorized_keys` esistenti;
- uninstall, doctor, mail-test;
- build dell'installer standalone;
- CI ShellCheck.
