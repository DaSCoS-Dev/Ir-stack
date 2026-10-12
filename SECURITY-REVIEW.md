# Security review - 0.2.0-rc1

Questa review confronta la baseline `0.2.0-dev` con la release candidate `0.2.0-rc1`.
L'obiettivo non è dimostrare che IR Stack sia "sicuro per definizione", ma rimuovere failure mode evitabili prima della pubblicazione e rendere espliciti i rischi residui.

## Sintesi

| Severità | Finding | Stato in rc1 |
|---|---|---|
| HIGH | file di configurazione eseguiti tramite `source` come root | FIXED |
| HIGH | uninstall poteva rimuovere il rollback prima di usarlo | FIXED |
| HIGH | bootstrap OpenWrt verificava solo una delle host key ma poteva salvarne più di una | FIXED |
| HIGH | audit rules potevano fallire/essere incomplete senza rendere fallita l'installazione | FIXED |
| MEDIUM/HIGH | lockdown preservava sempre `ESTABLISHED,RELATED` | FIXED, ora opt-in |
| MEDIUM | cursor SSH poteva essere perso/sovrascritto con stato vuoto | FIXED |
| MEDIUM | ban firewalld limitato alla zona di default | FIXED |
| MEDIUM | baseline SSH poteva essere accettata implicitamente durante reinstall/update | FIXED |
| MEDIUM | unità systemd potevano fallire senza Postfix per `ReadWritePaths` inesistente | FIXED |
| MEDIUM | SMTP autenticato consentiva TLS opportunistico | FIXED |
| MEDIUM | watchdog non distingueva servizi IR da dipendenze esterne | FIXED/MITIGATED |
| MEDIUM | CI non controllava tutti i driver e gli script POSIX OpenWrt | FIXED |
| LOW/MEDIUM | validazione semantica IP nel backend OpenWrt debole | FIXED |
| LOW | duplicati SPDX / hygiene CI | FIXED |

## SR-01 - Configurazione eseguibile come root

**Severità:** HIGH  
**Versione affetta:** 0.2.0-dev

### Problema

Installer e runtime caricavano file di configurazione con `source`/`.`. Una riga come:

```text
ALERT_EMAIL="$(comando)"
```

poteva quindi diventare esecuzione di codice con privilegi root.

### Correzione

La rc1 usa un parser `KEY=VALUE` data-only con allowlist delle chiavi supportate. I valori non vengono valutati dalla shell. Le chiavi sconosciute vengono rifiutate.

Il test di regressione in `tests/smoke.sh` verifica che una configurazione contenente `$(touch ...)` rimanga dato inerte.

### Nota operativa

I file di configurazione **non supportano commenti inline**. Usare righe di commento separate con `#`.

---

## SR-02 - Rollback rimosso troppo presto durante uninstall

**Severità:** HIGH  
**Versione affetta:** 0.2.0-dev

### Problema

`uninstall.sh` poteva eliminare `emergency-lockdown-rollback.sh` prima di eseguire il rollback. Se il lockdown era attivo, l'host poteva restare isolato proprio mentre veniva rimosso lo strumento di recupero.

### Correzione

La rc1 esegue prima il rollback e la pulizia best-effort degli oggetti IR Stack nei tre backend locali, poi rimuove binari e configurazione.

La disinstallazione non elimina pacchetti di sistema, Postfix o helper OpenWrt remoto.

---

## SR-03 - Verifica incompleta della host key OpenWrt

**Severità:** HIGH  
**Versione affetta:** 0.2.0-dev

### Problema

Il bootstrap mostrava il fingerprint di una host key ma poteva salvare più chiavi restituite da `ssh-keyscan`. Una chiave non confermata poteva quindi entrare nel `known_hosts` dedicato.

### Correzione

La rc1 seleziona una sola host key, calcola il fingerprint esattamente di quella riga e salva soltanto quella chiave. In modalità non interattiva è obbligatorio passare `--host-key SHA256:...`.

La modalità interattiva resta TOFU se l'amministratore non confronta il fingerprint tramite un canale indipendente.

---

## SR-04 - Copertura audit incompleta e fallimenti nascosti

**Severità:** HIGH  
**Versione affetta:** 0.2.0-dev

### Problema

Regole audit statiche potevano referenziare file o binari assenti; inoltre `augenrules --load || true` consentiva all'installer di dichiarare successo anche quando le regole non erano state caricate correttamente.

### Correzione

`refresh-audit-rules.sh` genera regole solo per oggetti realmente presenti, copre le directory `.ssh` esistenti oltre agli `authorized_keys` e rende bloccanti gli errori normali di `augenrules`.

Se auditd è in modalità immutable (`enabled=2`) viene restituito uno stato specifico: la nuova configurazione sarà effettiva dopo reboot e l'installer lo segnala chiaramente.

---

## SR-05 - Lockdown che preservava sessioni già aperte

**Severità:** MEDIUM/HIGH  
**Versione affetta:** 0.2.0-dev

### Problema

Il lockdown consentiva sempre `ESTABLISHED,RELATED`. Una connessione ostile già attiva poteva quindi continuare a transitare dopo l'isolamento.

### Correzione

Il default è ora:

```ini
LOCKDOWN_KEEP_ESTABLISHED="no"
```

La conservazione delle sessioni esistenti deve essere scelta esplicitamente. Il comportamento effettivo va comunque collaudato sul backend e sul connection tracking dell'host.

---

## SR-06 - Cursor journald SSH fragile

**Severità:** MEDIUM

### Correzione

Il cursor viene aggiornato atomicamente e non viene sostituito da uno stato vuoto. Un cursor invalido o un journal non leggibile produce warning, tentativo di alert e reinizializzazione esplicita invece di procedere silenziosamente.

---

## SR-07 - Firewalld ban applicato solo alla zona di default

**Severità:** MEDIUM

### Correzione

I ban dinamici firewalld usano una policy dedicata `ir-ban` da `ANY` verso `HOST` con target `CONTINUE` e rich rule DROP per gli indirizzi bannati. In questo modo il controllo non dipende dalla zona predefinita dell'interfaccia.

---

## SR-08 - Baseline SSH accettata implicitamente

**Severità:** MEDIUM

### Problema

Rigenerare automaticamente la baseline durante un update poteva trasformare una modifica ostile già presente in nuovo stato "normale".

### Correzione

La baseline viene creata solo se assente. Una baseline esistente non viene sovrascritta durante reinstall/update. Dopo una modifica autorizzata l'amministratore deve eseguire deliberatamente:

```bash
irctl ssh-baseline-accept
```

---

## SR-09 - Sandbox systemd dipendente da Postfix

**Severità:** MEDIUM

### Correzione

I path facoltativi, come `/var/spool/postfix`, usano la sintassi systemd con prefisso `-`, così l'assenza di Postfix non impedisce l'avvio dei watcher.

Le unità usano inoltre `ProtectSystem=strict`, `NoNewPrivileges=yes`, limitazioni address-family e altri hardening compatibili con la funzione del singolo servizio.

---

## SR-10 - SMTP autenticato con TLS opportunistico

**Severità:** MEDIUM

### Correzione

È stato introdotto `RELAY_TLS_MODE=verify|encrypt|may|none`. Se `RELAY_AUTH=yes`, l'installer rifiuta `may` e `none`. Le password possono essere fornite tramite file per evitare command history/process list; non vengono salvate in `ir-stack.conf`.

---

## SR-11 - Watchdog e servizi esterni

**Severità:** MEDIUM

### Correzione

Le unità interne IR Stack sono auto-repair. `auditd`, il Postfix gestito dallo stack e Fail2Ban vengono invece controllati in modalità alert-only: IR Stack non riavvia automaticamente un servizio esterno e non ne nasconde così il failure mode.

### Rischio residuo accettato

Un watchdog locale non può garantire di rilevare la disattivazione del proprio timer da parte di un attaccante root. Per garanzie forti serve monitoring esterno/out-of-band.

---

## SR-12 - Copertura SSH key oltre auditd

**Severità:** MEDIUM

La rc1 aggiunge un inventario piccolo e deterministico degli `authorized_keys` presenti: path, SHA256, UID/GID e mode. Il checker lo confronta con una baseline esplicitamente accettata. Questo copre anche creazioni/rimozioni che potrebbero sfuggire a una watch specifica su un file che non esisteva al momento dell'installazione.

Auditd resta la fonte di contesto forense; la baseline non lo sostituisce.

---

## SR-13 - OpenWrt remote helper e trusted sources

**Severità residua:** MEDIUM

Il dispatcher locale `ir-ban` impedisce di bannare indirizzi che ricadono in `TRUSTED_SOURCES`. Il forced-command OpenWrt limita la chiave a `check/status/ban/unban`, ma il router non possiede ancora una copia autonoma della allowlist trusted.

Conseguenza: un root compromesso sull'host IR che possiede la chiave dedicata potrebbe invocare direttamente il forced command e tentare di bannare una sorgente di gestione.

**Decisione rc1:** rischio documentato, non bloccante per RC. Hardening consigliato per release successiva: sincronizzare le trusted sources anche sul router e rifiutarle lato helper OpenWrt.

---

## SR-14 - Firewalld e connessioni già tracciate

**Severità residua:** LOW/MEDIUM

La semantica di isolamento va verificata sul firewall effettivo e sul connection tracking. `LOCKDOWN_KEEP_ESTABLISHED=no` esprime l'intento dello stack, ma un backend di alto livello come firewalld può interagire con stato già tracciato in modo diverso dal driver nftables/iptables dedicato.

**Raccomandazione:** testare lockdown + rollback da console su ogni classe di host prima di impostare `ENABLE_LOCKDOWN=yes`.

---

## SR-15 - Installazione non completamente transazionale

**Severità residua:** LOW/MEDIUM

L'installer crea backup e registra un `INSTALL_FAILED` in caso di errore. Non tenta però un rollback automatico generale di package, MTA e ogni configurazione esterna, perché un rollback automatico aggressivo può causare più danni dello stato parziale.

**Decisione:** comportamento esplicito e conservativo. Prima della produzione usare VM/staging e conservare accesso console.

---

## CI e supply chain

La rc1 estende i controlli a:

- tutti gli script Bash;
- driver firewall;
- script POSIX OpenWrt;
- build dell'installer standalone;
- esecuzione `--help` dell'installer generato;
- regression test sul parser config non eseguibile.

`actions/checkout` è pinnata al full commit SHA `3d3c42e5aac5ba805825da76410c181273ba90b1` (tag `v7`) con `persist-credentials: false`. Dependabot per GitHub Actions è attivo.

## Esito

I finding HIGH individuati in `0.2.0-dev` risultano corretti nella `0.2.0-rc1`. I rischi residui sono documentati e riguardano principalmente limiti architetturali o aspetti che devono essere collaudati nell'ambiente reale (firewall/connection tracking, observer locale, allowlist OpenWrt remota, installazione non completamente transazionale).
