# 4.07 - Host-Firewall mit nftables - sicherer Rollout: Erklärung

### Der Totmannschalter Schritt für Schritt
1. Template + `validate: nft -c -f %s` → Syntaxfehler erreichen den Host nie.
2. `sleep 60; nft delete table ...` im Hintergrund starten (`nohup`, eigener Prozess).
3. Regeln laden.
4. `meta: reset_connection` schließt Ansibles persistenten SSH-Master. Ohne das würde
   `wait_for_connection` die *bereits bestehende* Verbindung nutzen, die die Regel
   `established,related` am Leben hält - ein falsch positives Ergebnis.
5. `wait_for_connection` öffnet eine neue Verbindung. Erfolg → Rollback per `kill`
   abbrechen. Misserfolg → das Play scheitert für diesen Host, und 60 s später ist die
   Tabelle wieder weg.

### Die eigene Tabelle besitzen
`flush ruleset` ist in vielen Distributionsvorlagen Standard. In geteilten Kerneln und
Namespaces entfernt es Regeln anderer Besitzer. Im Lab würdest du DNS im Container
kaputt machen; auf einem Docker-Host das Netzwerk jedes Containers. Eine eigene Tabelle
plus `delete table` hält deine Änderungen atomar und abgegrenzt.

### Warum nftables.service nicht neu starten
Auf Debian führt `ExecStop` `nft flush ruleset` aus - ein Neustart löscht einmal fremde
Regeln. Aktivieren reicht: beim Booten lädt der Dienst dein Include.

### Nach Neustarts erneut anwenden
Die Datei kann unverändert sein, während der Kernelzustand weg ist (Container- oder
Host-Neustart ohne Dienst). Die Prüfung des *Live*-Zustands (`nft list table`) schließt
die Lücke - dieselbe Idee wie "die Wirkung prüfen, nicht die Datei" aus 1.01 und 1.03.

## Musterlösung

Anzeigen mit `lab solution 4.07`, anwenden mit `lab solve 4.07`.
