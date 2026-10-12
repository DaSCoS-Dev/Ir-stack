# IR Stack

[Italiano](README.md) | **English**

IR Stack is a lightweight **incident detection / identity monitoring** stack for Linux servers running systemd and auditd.
It originated from the guide published on SicurezzaReti and turns that monolithic baseline into a modular, reviewable project that can be installed interactively or unattended.

> It is not a SIEM and it does not claim to make a server invulnerable. Its goal is to increase the chance of **detecting sensitive changes quickly** and preserve enough context to reconstruct the event.

## What it monitors

- identity and privilege files: `/etc/passwd`, `shadow`, `group`, `sudoers*`;
- anomalous UID 0 accounts;
- system accounts with unexpected interactive shells;
- SSH configuration and existing `authorized_keys`;
- successful SSH logins through a journald cursor;
- changes to IR Stack files themselves;
- status of the path/timer/service units that make up the stack;
- optionally, emergency isolation through nftables, iptables, or firewalld backends;
- dynamic bans locally and/or on a remote OpenWrt router;
- optional Fail2Ban integration through a dedicated action.

## Differences from the installer published in the article

The original baseline generated everything from a single script. This version:

1. separates binaries, common library, audit rules, and systemd units;
2. includes an **interactive** installer that asks for email, trusted sources/IP/CIDR, SSH port, mail mode, and relay settings;
3. also works **non-interactively** through a configuration file, environment variables, or command-line flags;
4. does not require a trusted IPv4 address when lockdown remains disabled;
5. does not add `asterisk` to the whitelist unless the host actually requires it;
6. uses a timer + journald for SSH login monitoring, without depending on `/var/log/auth.log`;
7. implements a real maintenance window with automatic expiration;
8. includes `uninstall.sh`, `irctl doctor`, `irctl mail-test`, and dynamic audit-rule generation;
9. keeps an explicit baseline of `authorized_keys`, without automatically accepting the current state during updates;
10. treats configuration files as `KEY=VALUE` data, without executing them as shell;
11. can generate a standalone installer at `dist/install-ir-stack.sh`.

## Requirements

First officially supported release:

- Debian/Ubuntu/Raspberry Pi OS and other apt-based derivatives;
- systemd;
- auditd;
- bash;
- root privileges for installation and management.

Lockdown is **disabled by default** and must be tested from console access. It supports `nftables`, `iptables`, and `firewalld` without flushing the existing ruleset. `auto` prefers an active firewalld instance, then nftables, then iptables.

## Interactive installation

```bash
sudo ./install.sh
```

The installer proposes and validates:

- alert email address;
- mail mode: `existing`, `postfix-relay`, or `none`;
- SMTP relay and port, when needed;
- optional SMTP authentication;
- multiple trusted sources: individual IPv4/IPv6 addresses and/or CIDR networks;
- firewall backend `auto|nftables|iptables|firewalld|none`;
- optional Fail2Ban and remote OpenWrt integration;
- SSH port, automatically detected when possible;
- whitelist of service accounts allowed to have an interactive shell;
- lockdown enablement, default `no`;
- sshd `LogLevel VERBOSE`, default `yes`.

## Unattended installation

Example:

```bash
sudo ./install.sh \
  --non-interactive \
  --alert-email soc@example.net \
  --mail-mode postfix-relay \
  --relay-host mail.example.net \
  --relay-port 25 \
  --trusted-sources "192.168.2.43,10.0.10.98,10.0.20.0/24" \
  --firewall-backend auto \
  --ssh-port 22 \
  --enable-lockdown no
```

Or:

```bash
sudo ./install.sh --config ./examples/install.conf
```

## Mail modes

### `existing`

IR Stack does not modify the MTA. It uses the `sendmail` command already available on the system. This is the right choice when the server already has Postfix/Exim/msmtp or a configured local relay.

### `postfix-relay`

Installs/configures Postfix in satellite mode with `inet_interfaces=loopback-only`. It can use a relay without authentication or SASL/TLS. `RELAY_TLS_MODE` supports `verify|encrypt|may|none`; when SMTP authentication is enabled, IR Stack requires mandatory TLS (`verify` or `encrypt`).

### `none`

No email. Events remain available in journald and local logs.

## Main commands

```bash
irctl status
irctl check
irctl audit
irctl logs
irctl doctor
irctl mail-test
irctl refresh-audit
irctl ssh-baseline-show
irctl ssh-baseline-accept
```

### Maintenance window

```bash
irctl maintenance on 60
irctl maintenance status
irctl maintenance off
```

During maintenance, IR Stack continues recording events but suppresses email, escalation, and lockdown. The marker lives under `/run`, so it also disappears on reboot, and it still contains an epoch expiration time.

## Tests

```bash
irctl test-manual
irctl test-path
irctl test-ssh
irctl test-ir
irctl test-watch
```

## Installed layout

```text
/etc/ir-stack/
  ir-stack.conf
  identity-shell-whitelist

/usr/local/lib/ir-stack/
  common.sh

/usr/local/sbin/
  check-identity-anomalies.sh
  identity-incident-handler.sh
  ssh-login-alert.sh
  ir-stack-watch.sh
  ir-guardians-watchdog.sh
  emergency-lockdown.sh
  emergency-lockdown-rollback.sh
  refresh-audit-rules.sh
  refresh-ssh-key-audit.sh
  ssh-key-inventory.sh
  accept-ssh-key-baseline.sh
  irctl

/etc/audit/rules.d/
  40-ir-stack-identity.rules      # generated dynamically
  41-ir-stack-self.rules
  42-ir-stack-sshkeys.rules       # generated dynamically

/etc/systemd/system/
  ir-stack-*.service|timer|path
```

## Trusted sources

```ini
TRUSTED_SOURCES="192.168.2.43,10.0.10.98,10.0.20.0/24"
```

The same list protects lockdown and acts as the allowlist for `ir-ban`: an IP address belonging to those networks cannot be banned.

## Safe configuration parsing

`/etc/ir-stack/ir-stack.conf` is a `KEY=VALUE` file parsed through an allowlisted data parser: **it is not executed with `source`**. Comments must be on separate lines; inline comments are not supported.

SMTP credentials are not persisted in the IR Stack configuration file. For unattended deployments, `--relay-password-file` is preferred over passing a password directly on the command line.

## SSH-key baseline

IR Stack records path, SHA256, owner/group, and mode for existing `authorized_keys` files. Reinstalling does not overwrite an existing baseline. After an authorized change:

```bash
irctl ssh-baseline-show
irctl ssh-baseline-accept
```

Accepting the baseline must be an explicit administrative decision.

## Audit rules

Audit watches are generated only for files and binaries that actually exist. A normal `augenrules` failure stops installation instead of being ignored. If auditd is immutable (`enabled=2`), IR Stack reports that the new rules will become effective after reboot.

## Firewall, OpenWrt, and Fail2Ban

- [Firewall backends](docs/firewall-backends_eng.md)
- [Remote OpenWrt](docs/openwrt_eng.md)
- [Fail2Ban](docs/fail2ban_eng.md)

## Lockdown

Lockdown is deliberately separated from detection and starts **OFF**. Before enabling it:

- verify all trusted sources/IP/CIDR entries;
- verify the SSH port;
- make sure console/IPMI/KVM or another out-of-band access path is available;
- verify the firewall backend already used on the server;
- run a manual test and rollback.

IR Stack no longer flushes the firewall: it uses dedicated objects and a rollback procedure that removes only what it created. The selected backend must still be tested, and console/out-of-band access remains mandatory.

## Limitations and trust model

IR Stack runs on the same server it observes: an attacker with full root control can attempt to disable the monitoring system as well. Auditd, self-watch, and guardians improve telemetry and resilience, but **do not replace an external observer**.

The OpenWrt integration protects trusted sources through the normal `ir-ban` path; in rc1, the remote router does not yet replicate that allowlist independently. See `SECURITY-REVIEW_ENG.md` for residual risks and design decisions.

The installer creates backups and clearly records a failed installation, but it does not attempt a broad, aggressive rollback of packages, the MTA, or external configuration. Before production deployment, use staging/VMs and maintain console access.

## Build the standalone installer

```bash
./scripts/build-standalone.sh
```

This produces `dist/install-ir-stack.sh`, a single self-extracting file containing the project components required for installation.

## Updates

To update from a GitHub checkout, run `./install.sh` again: the existing configuration is used as the default and a backup is created under `/var/backups/ir-stack/` before changes are applied.

## Reference article

https://www.sicurezzareti.net/2026/09/ir-stack-file-integrity-monitoring-incident-response/

## License

Copyright (C) 2026 Dascos. The project is distributed under **GNU GPL-3.0-or-later**. Redistributions and modified versions must preserve the GPL terms and applicable copyright notices. See `LICENSE` and `CONTRIBUTING_ENG.md`.
