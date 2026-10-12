# Configuration

[Italiano](configuration.md) | **English**

Runtime file: `/etc/ir-stack/ir-stack.conf`.

## The file is data, not shell

Starting with `0.2.0-rc1`, configuration is read by an allowlisted `KEY=VALUE` parser: **it is not executed with `source`**.

Recommended format:

```ini
ALERT_EMAIL="soc@example.net"
TRUSTED_SOURCES="192.168.2.43,10.0.10.0/24"
ENABLE_LOCKDOWN="no"
```

Comments must be on separate lines:

```ini
# correct
SSH_PORT="22"
```

Do not use inline comments because the parser treats them as part of the value.

Unknown keys cause configuration loading to fail instead of being silently ignored.

## Main variables

| Variable | Meaning |
|---|---|
| `ALERT_EMAIL` | alert recipient |
| `MAIL_MODE` | `existing`, `postfix-relay`, `none` |
| `RELAY_HOST`, `RELAY_PORT` | SMTP relay |
| `RELAY_TLS_MODE` | `verify`, `encrypt`, `may`, `none` |
| `RELAY_AUTH` | `yes` / `no` |
| `RELAY_USER` | relay SASL username |
| `TRUSTED_SOURCES` | IPv4/IPv6 IP/CIDR list, e.g. `192.168.2.43,10.0.10.0/24` |
| `SSH_PORT` | SSH port kept reachable from trusted sources during lockdown |
| `ENABLE_LOCKDOWN` | `yes` / `no` |
| `LOCKDOWN_KEEP_ESTABLISHED` | `yes` / `no`, default `no` |
| `FIREWALL_BACKEND` | `auto`, `nftables`, `iptables`, `firewalld`, `none` |
| `BAN_BACKENDS` | `local`, `openwrt`, `local,openwrt` |
| `FAIL2BAN_INTEGRATION` | install the Fail2Ban action |
| `OPENWRT_REMOTE_ENABLE` | enable the OpenWrt client |
| `OPENWRT_HOST`, `OPENWRT_PORT`, `OPENWRT_USER` | OpenWrt SSH endpoint |
| `OPENWRT_IDENTITY_FILE` | dedicated private key |
| `OPENWRT_KNOWN_HOSTS` | dedicated host-key pinning file |

Service-account shell whitelist: `/etc/ir-stack/identity-shell-whitelist`, one username per line.

## SMTP TLS

For `MAIL_MODE=postfix-relay`:

- `verify`: mandatory TLS with certificate/name verification; preferred when the relay is configured correctly;
- `encrypt`: mandatory TLS, but with weaker authentication guarantees than `verify`;
- `may`: opportunistic TLS;
- `none`: no TLS.

If `RELAY_AUTH=yes`, the installer rejects `may` and `none`: SMTP credentials must not be sent over a channel that can downgrade to clear text.

SMTP credentials are not stored in `ir-stack.conf`: when the installer configures Postfix with SASL, they are written to `/etc/postfix/sasl_passwd` with 0600 permissions. For unattended deployments, `--relay-password-file` is preferable to `--relay-password` so the secret does not appear in command history/process listings.

## Trusted sources

Example:

```ini
TRUSTED_SOURCES="192.168.2.43,10.0.10.98,10.0.20.0/24,2001:db8:10::/64"
```

Individual hosts and IPv4/IPv6 CIDRs are accepted. Hosts are canonicalized as `/32` or `/128`. The same list is used by local lockdown and by the `ir-ban` dispatcher allowlist.

## SSH-key baseline

IR Stack keeps a baseline containing:

- pathname;
- SHA256 of the `authorized_keys` file;
- UID/GID;
- mode.

The file lives at `/var/lib/ir-stack/ssh-keys.baseline`.

A reinstall/update **does not automatically accept** a new state. After an authorized change:

```bash
irctl ssh-baseline-show
irctl ssh-baseline-accept
```

Accepting the baseline explicitly declares that the current key state is legitimate.

## Immutable audit mode

Audit rules are generated dynamically only for files/commands that exist. If auditd is configured with `enabled=2`, the ruleset remains immutable until reboot: the installer reports that the new rules require a reboot instead of pretending they are already active.

To check:

```bash
auditctl -s
irctl audit
```

## Lockdown and existing sessions

The default is:

```ini
LOCKDOWN_KEEP_ESTABLISHED="no"
```

During emergency lockdown, the stack does not automatically allow traffic for already established connections. Set it to `yes` only for a specific operational reason and after testing the selected backend.
