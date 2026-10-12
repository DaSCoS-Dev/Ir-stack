# Configurazione

File runtime: `/etc/ir-stack/ir-stack.conf`.

## Il file è dati, non shell

Dalla `0.2.0-rc1` la configurazione viene letta da un parser `KEY=VALUE` con allowlist: **non viene eseguita con `source`**.

Formato consigliato:

```ini
ALERT_EMAIL="soc@example.net"
TRUSTED_SOURCES="192.168.2.43,10.0.10.0/24"
ENABLE_LOCKDOWN="no"
```

I commenti devono stare su righe separate:

```ini
# corretto
SSH_PORT="22"
```

Non usare commenti inline, perché il parser li considera parte del valore.

Le chiavi non riconosciute fanno fallire il caricamento invece di essere ignorate silenziosamente.

## Variabili principali

| Variabile | Significato |
|---|---|
| `ALERT_EMAIL` | destinatario alert |
| `MAIL_MODE` | `existing`, `postfix-relay`, `none` |
| `RELAY_HOST`, `RELAY_PORT` | relay SMTP |
| `RELAY_TLS_MODE` | `verify`, `encrypt`, `may`, `none` |
| `RELAY_AUTH` | `yes` / `no` |
| `RELAY_USER` | username SASL relay |
| `TRUSTED_SOURCES` | lista IP/CIDR IPv4/IPv6, es. `192.168.2.43,10.0.10.0/24` |
| `SSH_PORT` | porta SSH mantenuta raggiungibile dalle trusted sources durante lockdown |
| `ENABLE_LOCKDOWN` | `yes` / `no` |
| `LOCKDOWN_KEEP_ESTABLISHED` | `yes` / `no`, default `no` |
| `FIREWALL_BACKEND` | `auto`, `nftables`, `iptables`, `firewalld`, `none` |
| `BAN_BACKENDS` | `local`, `openwrt`, `local,openwrt` |
| `FAIL2BAN_INTEGRATION` | installazione action Fail2Ban |
| `OPENWRT_REMOTE_ENABLE` | abilita client OpenWrt |
| `OPENWRT_HOST`, `OPENWRT_PORT`, `OPENWRT_USER` | endpoint SSH OpenWrt |
| `OPENWRT_IDENTITY_FILE` | chiave privata dedicata |
| `OPENWRT_KNOWN_HOSTS` | host key pinning dedicato |

Whitelist shell di servizio: `/etc/ir-stack/identity-shell-whitelist`, un username per riga.

## TLS SMTP

Per `MAIL_MODE=postfix-relay`:

- `verify`: TLS obbligatorio con verifica certificato/nome; è la scelta preferita quando il relay è configurato correttamente;
- `encrypt`: TLS obbligatorio, ma con garanzie di autenticazione meno forti rispetto a `verify`;
- `may`: TLS opportunistico;
- `none`: niente TLS.

Se `RELAY_AUTH=yes`, l'installer rifiuta `may` e `none`: credenziali SMTP non devono essere trasmesse su un canale che può degradare in chiaro.

Le credenziali SMTP non vengono salvate in `ir-stack.conf`: se l'installer configura Postfix con SASL finiscono in `/etc/postfix/sasl_passwd` con permessi 0600. Per unattended è preferibile `--relay-password-file` a `--relay-password`, così il segreto non finisce in command history/process list.

## Trusted sources

Esempio:

```ini
TRUSTED_SOURCES="192.168.2.43,10.0.10.98,10.0.20.0/24,2001:db8:10::/64"
```

Sono accettati host singoli e CIDR IPv4/IPv6. Gli host vengono canonicalizzati come `/32` o `/128`. La stessa lista viene usata dal lockdown locale e dall'allowlist del dispatcher `ir-ban`.

## Baseline SSH keys

IR Stack mantiene una baseline di:

- pathname;
- SHA256 del file `authorized_keys`;
- UID/GID;
- mode.

Il file vive sotto `/var/lib/ir-stack/ssh-keys.baseline`.

Una reinstallazione/update **non accetta automaticamente** un nuovo stato. Dopo una modifica autorizzata:

```bash
irctl ssh-baseline-show
irctl ssh-baseline-accept
```

Accettare la baseline significa dichiarare esplicitamente che lo stato corrente delle chiavi è legittimo.

## Audit immutable

Le regole audit sono generate dinamicamente soltanto per file/comandi presenti. Se auditd è configurato con `enabled=2`, il ruleset è immutable fino al reboot: l'installer segnala che le nuove regole richiedono un reboot invece di fingere che siano già attive.

Per controllare:

```bash
auditctl -s
irctl audit
```

## Lockdown e sessioni esistenti

Il default è:

```ini
LOCKDOWN_KEEP_ESTABLISHED="no"
```

In un emergency lockdown lo stack non concede automaticamente traffico alle connessioni già stabilite. Impostare `yes` solo se esiste un motivo operativo preciso e dopo test del backend.
