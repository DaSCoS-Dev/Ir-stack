# Architettura

```text
identity files ---> path/timer ---> checker ---> incident handler ---> mail/log
                         |             |                  |
                         |             |                  +--> lockdown dispatcher
                         |             |                         + nftables
                         |             |                         + iptables
                         |             |                         + firewalld
                         |             |
                         |             +--> SSH-key baseline diff
                         |
                         +--> dynamic audit rules

Fail2Ban / detector ---> ir-ban --------------------------> local firewall ban
                                                       +--> forced SSH ---> OpenWrt edge

journald/sshd ---> cursor parser ---> mail/log
IR files -------> self-watch ------> mail/log
systemd units --> guardians -------> auto-repair IR units / alert external deps
maintenance marker (/run/ir-stack/maintenance.until)
```

## Principi

- Detection, lockdown e ban dinamici sono separati.
- Il lockdown è opt-in e non svuota il firewall esistente.
- Trusted source multiple accettano host e CIDR IPv4/IPv6.
- `ir-ban` non banna mai un indirizzo appartenente alle trusted sources.
- Audit rules vengono generate solo per oggetti realmente presenti; gli errori di caricamento non vengono nascosti.
- Le chiavi SSH sono controllate sia tramite audit delle directory/file esistenti sia tramite inventario/baseline.
- OpenWrt usa una chiave dedicata con forced-command e host-key pinning dedicato, non una shell remota generica.
- Fail2Ban è un produttore opzionale di eventi ban, non una dipendenza del core.
- Le unità IR Stack possono essere auto-riparate dal guardian; servizi esterni importanti vengono soltanto segnalati.

## Limiti intenzionalmente dichiarati

### Observer locale

Un watchdog eseguito sullo stesso host non può garantire di rilevare lo spegnimento del proprio timer da parte di un attaccante root. Per una garanzia forte serve monitoring esterno.

### Baseline SSH

La baseline serve a rilevare divergenze di un insieme piccolo di file sensibili. Non sostituisce auditd e deve essere accettata esplicitamente dopo modifiche autorizzate.

### Firewall

La semantica precisa del connection tracking dipende dal backend e dall'ambiente. Ogni classe di host deve essere collaudata da console prima di abilitare lockdown automatico.
