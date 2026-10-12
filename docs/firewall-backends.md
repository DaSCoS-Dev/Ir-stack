# Firewall backends

IR Stack separa il **lockdown d'emergenza** dai **ban dinamici**.

## Lockdown locale

`FIREWALL_BACKEND=auto|nftables|iptables|firewalld|none`.

- `nftables`: crea una tabella `inet ir_stack_lockdown` separata. Non svuota il ruleset esistente e applica il ruleset IR in modo atomico.
- `iptables`: usa una chain `IR_STACK_LOCKDOWN` dedicata e la inserisce in testa a INPUT. Non esegue flush delle chain esistenti; in caso di apply fallito rimuove gli oggetti IR creati in quella fase.
- `firewalld`: crea una policy runtime `ir-lockdown` da `ANY` a `HOST`, con priorità negativa e target DROP; in caso di errore durante la costruzione rimuove la policy parziale.
- `auto`: preferisce firewalld se attivo, quindi un ambiente nftables già operativo, quindi iptables; su host nuovi può scegliere nftables.

Il rollback elimina esclusivamente gli oggetti creati da IR Stack.

### Connessioni già stabilite

Il default è:

```ini
LOCKDOWN_KEEP_ESTABLISHED="no"
```

Quindi nftables/iptables non aggiungono automaticamente una regola `ESTABLISHED,RELATED`. Se impostato a `yes`, le sessioni esistenti vengono preservate.

Il comportamento effettivo del connection tracking va comunque testato sul backend reale. In particolare firewalld è un livello di gestione più alto: non assumere che ogni stato già tracciato venga terminato nello stesso modo dei driver dedicati nftables/iptables.

## Trusted sources multiple

`TRUSTED_SOURCES` accetta IP singoli e CIDR IPv4/IPv6, separati da virgola, punto e virgola o whitespace:

```ini
TRUSTED_SOURCES="192.168.2.43,10.0.10.98,10.0.20.0/24,2001:db8:10::/64"
```

Gli indirizzi vengono validati/canonicalizzati. `ir-ban` rifiuta esplicitamente di bannare un IP che ricade in una trusted source.

## Ban dinamici

`BAN_BACKENDS=local`, `openwrt` oppure `local,openwrt`.

`ir-ban add 203.0.113.44` e `ir-ban del 203.0.113.44` sono il punto di integrazione per Fail2Ban e per detector futuri.

Backend locali:

- nftables: set dedicati nella tabella IR Stack;
- iptables: chain `IR_STACK_BAN` dedicata;
- firewalld: policy `ir-ban` da `ANY` verso `HOST`, target `CONTINUE`, con rich rule DROP per gli IP bannati.

`ban-flush` rimuove solo lo stato dinamico IR Stack del relativo backend.

## Regola di sicurezza operativa

Non impostare `ENABLE_LOCKDOWN=yes` su una classe di server prima di avere provato **apply e rollback da console/out-of-band**. Il lockdown è un meccanismo di contenimento e può interrompere servizi legittimi esattamente come previsto.
