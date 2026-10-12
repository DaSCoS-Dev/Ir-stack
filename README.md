# IR Stack

**Italiano** | [English](README_ENG.md)

IR Stack è uno stack leggero di **incident detection / identity monitoring** per server Linux con systemd e auditd.
Nasce dalla guida pubblicata su SicurezzaReti e trasforma quella baseline monolitica in un progetto modulare, verificabile e installabile in modo interattivo o unattended.

> Non è un SIEM e non promette di rendere un server invulnerabile. Il suo obiettivo è aumentare la probabilità di **accorgersi rapidamente di modifiche sensibili** e conservare abbastanza contesto da ricostruire l'evento.

## Cosa controlla

- file identità e privilegi: `/etc/passwd`, `shadow`, `group`, `sudoers*`;
- account UID 0 anomali;
- account di sistema con shell interattiva inattesa;
- configurazione SSH e `authorized_keys` esistenti;
- login SSH riusciti tramite cursor di journald;
- modifiche ai file dello stesso IR Stack;
- stato dei path/timer/service che compongono lo stack;
- opzionalmente, isolamento di emergenza tramite backend nftables, iptables o firewalld;
- ban dinamici locali e/o su OpenWrt remoto;
- integrazione Fail2Ban opzionale tramite action dedicata.

## Differenze rispetto all'installer pubblicato nell'articolo

La baseline originale generava tutto da un singolo script. Questa versione:

1. separa binari, libreria comune, audit rules e unità systemd;
2. include un installer **interattivo** che chiede email, trusted source/IP/CIDR, porta SSH, modalità mail e relay;
3. funziona anche **non-interattivamente** tramite file di configurazione, environment o flag;
4. non richiede un trusted IPv4 se il lockdown rimane disabilitato;
5. non inserisce `asterisk` nella whitelist se l'host non lo richiede;
6. usa un timer + journald per i login SSH, senza dipendere da `/var/log/auth.log`;
7. implementa una maintenance window reale con scadenza automatica;
8. include `uninstall.sh`, `irctl doctor`, `irctl mail-test` e generazione dinamica delle audit rule;
9. mantiene una baseline esplicita degli `authorized_keys`, senza accettare automaticamente lo stato durante gli update;
10. tratta i file config come dati `KEY=VALUE`, senza eseguirli come shell;
11. può generare un installer standalone in `dist/install-ir-stack.sh`.

## Requisiti

Prima release supportata ufficialmente:

- Debian/Ubuntu/Raspberry Pi OS e derivate apt-based;
- systemd;
- auditd;
- bash;
- root per installazione e gestione.

Il lockdown è **disabilitato di default** e va testato da console. Supporta `nftables`, `iptables` e `firewalld` senza svuotare il ruleset esistente. `auto` preferisce firewalld attivo, poi nftables, poi iptables.

## Installazione interattiva

```bash
sudo ./install.sh
```

L'installer propone e valida:

- indirizzo email degli alert;
- modalità mail: `existing`, `postfix-relay` o `none`;
- relay SMTP e porta, se richiesto;
- autenticazione SMTP opzionale;
- trusted source multiple: singoli IP e/o reti CIDR IPv4/IPv6;
- backend firewall `auto|nftables|iptables|firewalld|none`;
- integrazione opzionale Fail2Ban e OpenWrt remoto;
- porta SSH rilevata automaticamente quando possibile;
- whitelist degli account di servizio con shell interattiva;
- abilitazione del lockdown, default `no`;
- `LogLevel VERBOSE` di sshd, default `yes`.

## Installazione unattended

Esempio:

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

Oppure:

```bash
sudo ./install.sh --config ./examples/install.conf
```

## Modalità mail

### `existing`

IR Stack non modifica il MTA. Usa il comando `sendmail` già presente sul sistema. È la scelta corretta se il server possiede già Postfix/Exim/msmtp o un relay locale configurato.

### `postfix-relay`

Installa/configura Postfix in modalità satellite, con `inet_interfaces=loopback-only`. Può usare un relay senza autenticazione oppure SASL/TLS. `RELAY_TLS_MODE` supporta `verify|encrypt|may|none`; se è abilitata autenticazione SMTP, IR Stack richiede TLS obbligatorio (`verify` o `encrypt`).

### `none`

Nessuna email. Gli eventi rimangono in journald e nei log locali.

## Comandi principali

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

Durante la maintenance IR Stack continua a registrare eventi ma sopprime email, escalation e lockdown. Il marker è sotto `/run`, quindi sparisce anche al reboot, e contiene comunque una scadenza epoch.

## Test

```bash
irctl test-manual
irctl test-path
irctl test-ssh
irctl test-ir
irctl test-watch
```

## Layout installato

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
  40-ir-stack-identity.rules      # generata dinamicamente
  41-ir-stack-self.rules
  42-ir-stack-sshkeys.rules       # generata dinamicamente

/etc/systemd/system/
  ir-stack-*.service|timer|path
```

## Trusted sources

```ini
TRUSTED_SOURCES="192.168.2.43,10.0.10.98,10.0.20.0/24"
```

La stessa lista protegge il lockdown e funge da allowlist per `ir-ban`: un IP compreso in queste reti non può essere bannato.

## Configurazione sicura

`/etc/ir-stack/ir-stack.conf` è un file `KEY=VALUE` interpretato da un parser con allowlist: **non viene eseguito con `source`**. I commenti devono stare su righe separate; i commenti inline non sono supportati.

Le credenziali SMTP non vengono persistite nel file IR Stack. Per deploy unattended è preferibile `--relay-password-file` rispetto a una password passata direttamente sulla command line.

## Baseline delle chiavi SSH

IR Stack registra path, SHA256, owner/group e mode degli `authorized_keys` presenti. Una reinstallazione non sovrascrive una baseline esistente. Dopo una modifica autorizzata:

```bash
irctl ssh-baseline-show
irctl ssh-baseline-accept
```

L'accettazione della baseline deve essere una decisione amministrativa esplicita.

## Audit rules

Le watch audit vengono generate solo per file e binari realmente presenti. Un fallimento normale di `augenrules` interrompe l'installazione invece di essere ignorato. Se auditd è immutable (`enabled=2`), IR Stack segnala che le nuove regole diventeranno effettive dopo reboot.

## Firewall, OpenWrt e Fail2Ban

- [Firewall backends](docs/firewall-backends.md)
- [OpenWrt remoto](docs/openwrt.md)
- [Fail2Ban](docs/fail2ban.md)

## Lockdown

Il lockdown è volutamente separato dalla detection e parte **OFF**. Prima di abilitarlo:

- verifica tutte le trusted source/IP/CIDR;
- verifica la porta SSH;
- accertati di avere console/IPMI/KVM o altro accesso out-of-band;
- verifica il backend firewall già usato sul server;
- esegui un test manuale e un rollback.

IR Stack non esegue più flush del firewall: usa oggetti dedicati e un rollback che rimuove solo ciò che ha creato. Rimane comunque obbligatorio collaudare il backend scelto e mantenere accesso console/out-of-band.

## Limiti e modello di fiducia

IR Stack gira sul server che osserva: un attaccante con controllo root completo può tentare di disattivare anche il sistema di monitoring. Auditd, self-watch e guardian aumentano telemetria e resilienza, ma **non sostituiscono un osservatore esterno**.

L'integrazione OpenWrt protegge le trusted source nel normale percorso `ir-ban`; nella rc1 il router remoto non replica ancora autonomamente quella allowlist. Vedi `SECURITY-REVIEW.md` per rischi residui e decisioni di progetto.

L'installer crea backup e segnala chiaramente un'installazione fallita, ma non tenta un rollback generale e aggressivo di package/MTA/configurazioni esterne. Prima del deploy di produzione usare staging/VM e accesso console.

## Build installer standalone

```bash
./scripts/build-standalone.sh
```

Produce `dist/install-ir-stack.sh`, un singolo file self-extracting che contiene il progetto necessario all'installazione.

## Aggiornamenti

Per aggiornare da un checkout GitHub, eseguire nuovamente `./install.sh`: la configurazione esistente viene usata come default e prima delle modifiche viene creato un backup sotto `/var/backups/ir-stack/`.

## Articolo di riferimento

https://www.sicurezzareti.net/2026/09/ir-stack-file-integrity-monitoring-incident-response/

## Licenza

Copyright (C) 2026 Dascos. Il progetto è distribuito sotto **GNU GPL-3.0-or-later**. Le redistribuzioni e le versioni modificate devono mantenere le condizioni GPL e gli avvisi di copyright applicabili. Vedi `LICENSE` e `CONTRIBUTING.md`.
