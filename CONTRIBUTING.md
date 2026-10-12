# Contributing

Prima di una pull request:

```bash
./tests/smoke.sh
shellcheck install.sh uninstall.sh src/bin/* src/lib/*.sh scripts/*.sh tests/*.sh
```

Le modifiche ai componenti di sicurezza devono spiegare:

- minaccia coperta;
- possibili falsi positivi;
- comportamento durante maintenance;
- failure mode;
- procedura di rollback.

## Licenza e copyright delle contribuzioni

Inviando una contribuzione dichiari di avere il diritto di pubblicarla sotto GPL-3.0-or-later. Conservi il copyright sulla tua contribuzione; non rimuovere gli avvisi di copyright esistenti e aggiungi il tuo avviso quando una modifica sostanziale lo richiede. Le opere derivate distribuite devono rispettare la GPL-3.0-or-later.
