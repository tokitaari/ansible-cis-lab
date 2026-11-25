# 4.09 - Systemprotokollierung: ein Logger je Host, gewählt über Daten

*[English](README.md)*

| Stufe | Schwierigkeit | Zeit | CIS-Bezug | Hosts |
|---|---|---|---|---|
| Stufe 4 - Fortgeschritten | ★★★★☆ | ~60 Min. | 6.2 System logging (L1) | `targets` |

**Konzepte:** `choice by data + assert`, `systemd drop-ins and masking`, `whole-config check before restart`, `handlers with listen`, `service across systemd and OpenRC`

## Ziel

Gib jedem Target genau einen vollständig konfigurierten Systemlogger - journald, rsyslog oder BusyBox-syslogd, je OS-Familie über Daten gewählt - und stelle sicher, dass die Einstellungen die wirksamen sind, nicht nur die in deiner Datei.

## Hintergrund

Der Benchmark verlangt, je Host einen Logger zu wählen und ihn vollständig zu konfigurieren.
Welcher es ist, ist eine Entscheidung, also gehört sie in Daten und nicht in eine Kette von
`when:`-Bedingungen. In dieser Übung folgt die Wahl dem, was die Distributionen bei einer echten
Installation tun:

| Familie | Logger | Was du konfigurierst |
|---|---|---|
| Debian, Suse, Archlinux | nur journald | ein Drop-in in `/etc/systemd/journald.conf.d/` |
| RedHat | rsyslog (liest das Journal) und journald | das Paket `rsyslog`, ein Drop-in in `/etc/rsyslog.d/`, das journald-Drop-in |
| Alpine | BusyBox-`syslogd` (OpenRC-Dienst `syslog`) | `/etc/conf.d/syslog`, den Runlevel |

Eine Datei, die du schreibst, ist noch nicht die wirksame Einstellung: Andere Dateien können nach
deiner gelesen werden, ein Daemon kann mehr als einen Neustart brauchen, und eine kaputte Zeile
hält einen Daemon nicht unbedingt vom Start ab. Lektion L15 erklärt jeden dieser Punkte; sieh dir
die Targets an, bevor du etwas schreibst.

## Anforderungen

- [ ] Der Logger jedes Hosts kommt aus Daten: ein Dict mit `ansible_facts.os_family` als Schlüssel und den Werten der Tabelle. Das Play bricht mit einer klaren Meldung ab, wenn der Wert eines Hosts nicht `journald`, `rsyslog` oder `syslogd` ist.
- [ ] Jeder systemd-Host: Deine Einstellungen stehen in einem Drop-in unter `/etc/systemd/journald.conf.d/`, und wirksam (so, wie `systemd-analyze cat-config systemd/journald.conf` sie auflistet, der letzte Wert gewinnt) sind `Storage=persistent`, `Compress=yes` und eine Größengrenze `SystemMaxUse=<n>` (`K`, `M`, `G` oder `T` erlaubt); auf den Hosts mit nur journald zusätzlich `ForwardToSyslog=no`. journald schreibt wirklich nach `/var/log/journal`.
- [ ] RedHat-Familie: `rsyslog` installiert, aktiviert und laufend; ein Drop-in in `/etc/rsyslog.d/` setzt `$FileCreateMode 0640` (oder strenger); die ganze rsyslog-Konfiguration besteht `rsyslogd -N1`, bevor rsyslog neu startet; kein Netzwerk-Input (`imtcp`, `imudp`); `/var/log/messages` und `/var/log/secure` sind nicht lockerer als 0640; eine Testnachricht kommt in `/var/log/messages` an.
- [ ] Alpine: `syslog` steht im Runlevel `default` und läuft, mit den Rotationsoptionen `-s <KB>` und `-b <n>` in `SYSLOGD_OPTS` von `/etc/conf.d/syslog`, und der laufende Daemon nutzt sie.
- [ ] Ein Daemon startet nur neu, wenn sich seine Konfiguration geändert hat (Handler). Zweiter Lauf: `changed=0`.

## Vorgehen

```bash
lab start 4.09            # legt /lab/work/4.09/ an
cd /lab/work/4.09
# playbook.yml schreiben, dann ausführen:
ansible-playbook playbook.yml
lab check 4.09            # prüft den Zustand und dass ein zweiter Lauf nichts ändert
```

Festgefahren? `lab hint 4.09 1` (sanft) ... `lab hint 4.09 3` (fast die Lösung).  
Bestanden? Lies `lab explain 4.09` - dort stehen Stolperfallen und Praxis-Hinweise.
Host kaputt? `./lab.sh reset <host>` auf dem Host stellt ihn wieder her.

## Bonus (optional)

- Gib der Debian-Familie rsyslog statt nur journald (auf einem zurückgesetzten Host - `lab check` erwartet dort journald). Was muss `ForwardToSyslog` jetzt sein, und warum braucht die RedHat-Familie das nicht?
- `find /var/log -type f -perm /0137` listet die Dateien, die lockerer als 0640 sind. Welche sind es auf einem frischen Target, wer legt sie an, und welche darfst du verschärfen, ohne ein Programm zu brechen?
- Leite die Logs an einen zentralen Host weiter (rsyslog `omfwd` oder `systemd-journal-upload`). Was schützt die Nachrichten unterwegs, und was passiert, solange der zentrale Host nicht erreichbar ist?
- rsyslog schreibt einfache Dateien. Welche Familie rotiert sie, mit welchem Werkzeug, und wo ist das konfiguriert?
