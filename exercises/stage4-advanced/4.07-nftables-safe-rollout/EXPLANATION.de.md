# 4.07 - Host-Firewall mit nftables - sicherer Rollout: Erklärung

### Was der Check prüft
`lab check 4.07` führt `check.yml` auf den sieben Hosts aus, danach dein Playbook noch einmal
mit `--check`, und erwartet `changed=0`. `check.yml` prüft:
- `nft list table inet cis_filter` gelingt, und die Ausgabe enthält den Input-Hook mit
  `policy drop`, `tcp dport 22`, `ct state established,related accept` und den Forward-Hook
  mit `policy drop`.
- Die Persistenzdatei der Distribution (Debian und Arch `/etc/nftables.conf`, RedHat
  `/etc/sysconfig/nftables.conf`, Alpine `/etc/nftables.nft`) enthält das `include` von
  `/etc/cis/nftables-cis.nft` und keine Zeile `flush ruleset`.

Er prüft nicht den SSH-Quellbereich, die ICMP-Regeln, die Output-Policy, den aktivierten Dienst
und den Totmannschalter. Das musst du selbst richtig machen; der `--check`-Lauf zeigt nur, dass
ein zweiter Lauf nichts ändern würde.

### So funktioniert es

#### Der Totmannschalter Schritt für Schritt
1. Template + `validate: nft -c -f %s` → Syntaxfehler erreichen den Host nie.
2. `sleep 60; nft delete table ...` im Hintergrund starten. `nohup` und die Umleitungen sind
   Hygiene: In Tests überlebten ein Job mit einfachem `&`, einer mit `nohup` und Umleitungen
   und einer mit `async` + `poll: 0` den Tod des SSH-Masters.
3. Regeln laden.
4. `meta: reset_connection` schließt Ansibles persistenten SSH-Master, sodass die Tasks nach
   dem Test eine neue Verbindung unter den neuen Regeln öffnen. Es macht den Test nicht erst
   ehrlich: `wait_for_connection` öffnet bei jedem Versuch eine eigene Verbindung. Gemessen
   mit verworfenen neuen Verbindungen lief es mit und ohne Reset in das Timeout, während ein
   gewöhnliches `ping` über die alte Verbindung noch antwortete (`established,related` hält sie
   am Leben) - deshalb ist ein einfaches `ping` kein Test.
5. `wait_for_connection` mit `timeout: 20`. Erfolg → Rollback per `kill` abbrechen.
   Misserfolg → das Play scheitert für diesen Host, und 60 s später ist die Tabelle wieder weg.

Das Timeout muss deutlich unter der Rollback-Verzögerung bleiben (Standard des Moduls: 600 s).
Gemessen mit 15 s Rollback: Mit `timeout: 5` scheiterte der Task wie gewollt (`timed out waiting
for ping module test`); mit `timeout: 40` wurde er nach 18 s grün, weil der Rollback die Tabelle
gelöscht hatte und SSH wieder ging - der Rollback selbst bestand den Test. Ein einzelner Versuch
gegen eine verwerfende Firewall blockiert außerdem von sich aus (11 s bei `timeout: 5`), lass also
einen Puffer: Die Lösung nimmt 20 gegen 60.

#### Die eigene Tabelle besitzen
`flush ruleset` ist in vielen Distributionsvorlagen Standard. In geteilten Kerneln und
Namespaces entfernt es Regeln anderer Besitzer. Eine eigene Tabelle plus `delete table` hält
deine Änderungen atomar und abgegrenzt. Gemessen auf dem Target debian: Vor dem Flush zeigte
`nft list tables` `ip nat` (Docker) und `inet cis_filter`, danach nichts, und das Target konnte
den Namen eines anderen Containers nicht mehr auflösen. Auf einem Docker-Host würdest du das
Netzwerk jedes Containers kaputt machen. `./lab.sh reset <host>` stellt ein Target wieder her.

#### Warum nftables.service nicht neu starten
Ein Neustart ist ein Stopp plus ein Start, und der Stopp der meisten Paket-Units flusht.
Aktivieren reicht: beim Booten lädt der Dienst dein Include. Vertraue nicht dem Namen der Unit,
sondern lies sie (`systemctl cat nftables.service`, auf Alpine `/etc/init.d/nftables`); die
Tabelle unten zeigt, was die Lab-Images enthalten.

#### Nach Neustarts erneut anwenden
Die Datei kann unverändert sein, während der Kernelzustand weg ist (Container- oder
Host-Neustart ohne Dienst). Die Prüfung des *Live*-Zustands (`nft list table`) schließt
die Lücke - dieselbe Idee wie "die Wirkung prüfen, nicht die Datei" aus 1.01 und 1.03.

### Unterschiede je Familie

| os_family | Hosts | Persistenzdatei | Init und Unit | Stopp und Reload |
|---|---|---|---|---|
| Debian | debian, ubuntu | `/etc/nftables.conf` | systemd, `Type=oneshot`, `RemainAfterExit=yes` | `ExecStop` ist `nft flush ruleset`; `ExecReload` lädt die Datei |
| RedHat | rocky, alma, fedora | `/etc/sysconfig/nftables.conf` | systemd, `Type=oneshot`, `RemainAfterExit=yes` | `ExecStop` und `ExecReload` beginnen beide mit `flush ruleset` |
| Suse | opensuse | - | systemd | ausgenommen: firewalld ist das übliche Frontend |
| Archlinux | arch | `/etc/nftables.conf` | systemd, `Type=oneshot` | kein `ExecStop`, kein `RemainAfterExit` |
| Alpine | alpine | `/etc/nftables.nft` | OpenRC, `/etc/init.d/nftables` | `stop()` flusht; `reload()` lädt nur die Datei; `save_on_stop` steht standardmäßig auf `no` |

Die Units wurden gelesen, nachdem `lab solve 4.07` das Paket installiert hatte (nftables ist
standardmäßig nur auf arch installiert).

### Stolperfallen und gemessene Fakten

| Symptom | Ursache | Lösung |
|---|---|---|
| `has no attribute 'default_ipv4'` | `gather_subset: min` lässt die Netzwerk-Facts weg | sie sammeln (der Standard oder `min,network`) |
| `wait_for_connection` wird grün, obwohl nichts getestet wurde | das Timeout ist länger als die Rollback-Verzögerung, der Rollback hat den Zugang wiederhergestellt | das Timeout deutlich unter der Verzögerung halten |
| `[WARNING]: reset_connection task does not support when conditional` | das `when` des umgebenden Blocks wird an den `meta`-Task vererbt | nur eine Warnung; die Lösung besteht auf allen sieben Hosts (nicht untersucht, ob der Reset übersprungen wird, wenn die Bedingung falsch ist) |
| Dockers DNS ist weg, andere Container lösen nicht auf | `flush ruleset` hat die Tabelle `ip nat` gelöscht | nie flushen; nur `inet cis_filter` verwalten |
| die Tabelle ist nach einem Neustart weg, die Datei unverändert | Regeln im Kernel werden nicht durch die Datei persistiert | den Live-Zustand prüfen und den Dienst aktivieren |
| fremde Regeln verschwinden nach einem Neustart des Dienstes | `ExecStop` führt `nft flush ruleset` aus (debian, ubuntu, rocky, alma, fedora) | nur `enabled: true` verwenden |

### Praxis-Hinweise
- Dasselbe Muster - Rollback scharf stellen, ändern, mit einer neuen Verbindung testen,
  entschärfen - schützt jede Änderung am Pfad, über den du arbeitest (sshd, Routen, VPN).
- Wo firewalld, ufw oder ein anderes Werkzeug die Regeln besitzt, steht eine eigene Tabelle
  daneben. Entscheide, welches Werkzeug die Policy besitzt, bevor du ein zweites ergänzt.

### Weiterführend
- Lektion [L13 - Host-Firewall mit nftables](../../../docs/lessons/L13-host-firewall-nftables.de.md): die Konzepte vor dieser Übung, mit Demos und Selbsttest-Fragen.
- [Container-Grenzen](../../../docs/CONTAINER_LIMITS.de.md): warum das Lab nie das Regelwerk flusht.

## Musterlösung

Anzeigen mit `lab solution 4.07`, anwenden mit `lab solve 4.07`.
