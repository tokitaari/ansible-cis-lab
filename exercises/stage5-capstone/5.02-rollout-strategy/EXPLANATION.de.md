# 5.02 - Rollout-Strategie: Vorabprüfung, Canary, Wellen: Erklärung

### Was der Check prüft
`lab check 5.02` führt nur `check.sh` aus; `meta.yml` sagt `idempotency: false`, einen zweiten
Lauf gibt es also nicht. Das Skript liest `rollout.yml` als YAML und erwartet mindestens drei
Plays, `any_errors_fatal: true` im ersten, ein erstes `serial`-Play, dessen `serial` eine Liste
mit mindestens zwei Einträgen ist und das `max_fail_percentage` 0 hat, und den Namen
`cis_rollout_confirm` irgendwo in der Datei. Danach startet es das Playbook einmal mit `--check`
und ohne Bestätigung und erwartet einen Fehlschlag, dessen Log `cis_rollout_confirm` nennt.

Es wird nichts ausgerollt. Der Check schaut weder auf die Vorabprüfungs-Tasks noch auf die
Canary-Hosts, die Nachprüfung oder die echten Wellengrößen, und er nimmt das erste Play mit
`serial` als *das* Wellen-Play. Ob dein Rollout sicher ist, beurteilst du selbst: Lass ihn
einmal echt laufen.

### So funktioniert es

#### Warum es jedes Teil gibt
- **Vorabprüfung mit `any_errors_fatal`**: ist ein Host schon vor dem Start kaputt, soll ein
  Mensch draufschauen - keine halb ausgerollte Flotte.
- **Bestätigungsvariable**: Härtung ändert Authentifizierung und Netzwerkregeln. Ein
  Pflicht-`-e cis_rollout_confirm=true` verhindert "ich wollte nur den Check-Modus"-Unfälle und
  steht in den Joblogs.
- **Canary**: ein Host pro wichtiger Plattform fängt plattformspezifische Fehler früh.
- **`serial` + `max_fail_percentage: 0`**: ein Fehler innerhalb einer Welle stoppt den Rest des
  Laufs (siehe *Wellen*).
- **Nachprüfung mit neuer Verbindung**: der bestehende SSH-Master überlebt viele Fehler; nur ein
  *frischer* Login beweist, dass der nächste Operator noch hineinkommt.

#### Vorabprüfung und Sperre
"Erreichbar" und "Python vorhanden" deckt das Fact-Gathering ab; ein Host ohne Python scheitert
dort (Alpine vor 0.02: `interpreter /usr/bin/python3 not found`). Die Bestätigung ist ein
`assert` mit `run_once`. Er läuft auch unter `--check`, ein Trockenlauf kann die Sperre also
nicht überspringen. Die lesenden Sonden (`sshd -t`, `visudo -c`, `df`) brauchen
`check_mode: false`; sonst überspringt `--check` sie, und die Vorabprüfung besteht, ohne
hinzusehen.

#### Freier Platz: was ein Host über sich wissen kann
`ansible_facts.mounts` wirkt wie die naheliegende Quelle, aber die Facts behalten einen Mount
nur, wenn sein Device mit `/` oder `\` beginnt oder `:/` enthält (NFS: `host:/export`), und sie
überspringen `fstype none`. Der `overlay`-Root eines Containers und `tmpfs` erfüllen nichts davon:
im Lab gibt es keinen Eintrag für `/`, und ein `default(0)` macht daraus "0 MB frei" auf jedem
Host. Mit `gather_subset: min` gibt es gar kein `mounts`. `df -Pk /` fragt stattdessen den Kernel
und funktioniert überall (`-P` ist POSIX, auch busybox; `-k` legt die Einheit fest):
```yaml
- ansible.builtin.command: df -Pk /
  register: cis_df_root
  changed_when: false
  check_mode: false
- ansible.builtin.assert:
    that: (cis_df_root.stdout_lines[-1].split()[3] | int) * 1024 >= 209715200
```
Selbst die richtige Zahl kann täuschen: Bei **Thin Provisioning** sieht ein Host den freien Platz
seiner *virtuellen* Platte, nicht den des Speichers dahinter. Im Lab melden die Targets die
Kapazität der WSL2-/Docker-Desktop-VHDX, während das Windows-Laufwerk, das sie enthält, fast voll
sein kann; qcow2-Images, Thin-LVM-Pools, VMware-Thin-Disks und SAN-LUNs verhalten sich genauso.
Die Kapazität des darunterliegenden Speichers gehört ins Monitoring der Plattform.

#### Wellen
Ein Prozentwert in `serial` ist ein Anteil der Hosts **im Play** (nach `--limit`), abgerundet,
mindestens eins - nicht ein Anteil der übrigen Hosts. Das dritte Play hat im Lab sechs Hosts
(acht minus zwei Canarys), `[1, "30%", "100%"]` ergibt also Wellen mit 1, 1 und 4 Hosts
(gemessen). Bei 2.000 Servern ergibt `[1, 10, "5%", "25%", "100%"]` 1, 10, 100, 500 und die
restlichen 1.389.

`max_fail_percentage: 0` stoppt keine Welle mit einem Host - fällt ihr einziger Host aus, bleibt
keiner übrig, und der Lauf endet ohnehin. Wirksam ist es innerhalb einer Welle mit mehreren
Hosts: ohne den Wert machen die gesunden Hosts dieser Welle weiter (und die nächste Welle
startet); eine Welle, in der jeder Host ausfällt, beendet den Lauf in jedem Fall. Die Schwelle
ist ein Anteil der **Welle**, der Vergleich ist strikt: vier Hosts, zwei ausgefallen: 50 macht
weiter, 49 stoppt; einer ausgefallen: 25 macht weiter, 24 stoppt. Ein nicht erreichbarer Host
zählt als ausgefallen. Im Lab zeigt nur die letzte Welle (vier Hosts) die Einstellung: ist
`fedora` kaputt, überspringen `opensuse`, `arch` und `alpine` bei `0` die nächsten Tasks und die
Nachprüfung und führen sie bei `100` aus.

#### Was pro Welle läuft
Unter `serial` läuft das ganze Play einmal pro Welle: Tasks, `post_tasks` und Handler.
`run_once` läuft einmal pro Welle, auf deren erstem Host. Ein scheiternder `run_once`-assert
beendet den Lauf auch ohne `any_errors_fatal`, und `any_errors_fatal` an einem Block beendet das
ganze Play, nicht nur den Block.

#### Nachprüfung
`meta: reset_connection` wirft die dauerhafte Verbindung weg, der nächste Task loggt sich also
neu ein. `wait_for_connection` öffnet bei jedem Versuch eine eigene Verbindung (siehe 4.07) und
gelingt nur, wenn ein Login klappt; `sshd -T` zeigt danach die wirksamen Einstellungen. Vergleiche
das Schlüsselwort ohne Beachtung der Groß-/Kleinschreibung: arch (OpenSSH 10.6) gibt
`PermitRootLogin no` aus, die anderen Hosts schreiben es klein.

#### Berichte über Wellen hinweg
Unter `serial` ist `ansible_play_hosts` **nicht** die aktuelle Welle: Es enthält jeden nicht
gescheiterten Host des Plays, auch die noch kommenden Wellen. `ansible_play_batch` ist die
aktuelle Welle. Ein `run_once`-Bericht, der für jeden Eintrag in `ansible_play_hosts`
`hostvars[h].cis_summary` liest, bricht deshalb in Welle 1 ab (`has no attribute
'cis_summary'`) - die 5.01-Rolle tat genau das, bis der Rollout wirklich lief.
`ansible_play_batch` würde nicht abbrechen, aber jede Welle würde den Bericht mit nur ihren
eigenen Hosts überschreiben. Die 5.01-Rolle berichtet jeden Host, der schon eine Zusammenfassung
hat; `hostvars` bleiben über Plays hinweg erhalten, die Canarys bleiben also drin, und die letzte
Welle schreibt den vollständigen Bericht:
```yaml
cis_report_hosts: "{{ groups['all'] | map('extract', hostvars) | selectattr('cis_summary', 'defined') | map(attribute='inventory_hostname') | sort }}"
```

### Unterschiede je Familie

| os_family | Hosts | `sshd` / `visudo` | `df` | Hinweise |
|---|---|---|---|---|
| Debian | debian, ubuntu | `/usr/sbin` | `/usr/bin` | `sshd -T` klein geschrieben |
| RedHat | rocky, alma, fedora | `/sbin` (rocky, alma), `/usr/sbin` (fedora) | `/bin` (rocky, alma), `/usr/sbin` (fedora) | `sshd -T` klein geschrieben |
| Suse | opensuse | `/usr/sbin` | `/usr/bin` | `visudo -c` endet auf einem frischen Host mit 1 (`/usr/etc/sudoers` hat Modus 0444); die Lösung toleriert genau diese Meldung (siehe 1.05) |
| Archlinux | arch | `/usr/bin` | `/usr/bin` | `sshd -T` gibt `PermitRootLogin` aus |
| Alpine | alpine | `/usr/sbin` | `/bin` (BusyBox) | `df -Pk /` funktioniert; kein Python vor 0.02 (`requires`) |

Die Verzeichnisse sind das, was `command -v` ausgab (L14-Messung). Die Lösung ruft
`/usr/sbin/sshd` und `/usr/sbin/visudo` auf und lief auf allen acht Hosts durch.

### Stolperfallen und gemessene Fakten

| Symptom | Ursache | Lösung |
|---|---|---|
| "only 0.0 MB free on /" auf jedem Host | die Facts haben keinen Eintrag für den `overlay`-Root, `default(0)` versteckt das | `df -Pk /` lesen |
| `has no attribute 'cis_summary'` in Welle 1 | `ansible_play_hosts` listet Hosts von Wellen, die nicht gelaufen sind | über die Hosts berichten, die eine Zusammenfassung haben |
| Wellen weichen von deiner Rechnung ab | ein Prozentwert zählt die Hosts des Plays, abgerundet; `--limit` verkleinert das Play | aus der Play-Größe rechnen |
| der Lauf geht nach einem Fehler weiter | der Standard toleriert Fehler in einer Welle mit mehreren Hosts | `max_fail_percentage: 0` (strikt, Anteil der Welle) |
| die Vorabprüfung besteht, ohne zu prüfen | ein lesendes `command` wird unter `--check` übersprungen | `check_mode: false` |
| die Nachprüfung findet `permitrootlogin` auf arch nicht | OpenSSH 10.6 schreibt das Schlüsselwort gemischt | mit `(?i)` vergleichen |
| der Berichtsfehler zeigt sich nie | `--check` erreicht den Bericht nie mit echten Daten | den Rollout echt gegen eine Staging-Flotte testen |

### Praxis-Hinweise
- Wähle Canarys pro Plattform und Rolle, nicht nach Größe; es geht um je einen Host jeder
  abweichenden Art.
- Nach einem abgebrochenen Lauf listet das Recap nur die Hosts, die so weit kamen: vergleiche es
  mit der Hostliste und lege vorher fest, wie eine halb fertige Welle repariert wird (`--limit`,
  Reset).
- `-e cis_rollout_confirm=true` bleibt im Joblog sichtbar - eine Spur, wer was bestätigt hat.
- Freier Platz im Host sagt nichts über den Speicher dahinter; beobachte das im Monitoring der
  Plattform.

### Weiterführend
- Lektion [L14 - Production rollout](../../../docs/lessons/L14-production-rollout.de.md): Fehlersemantik, `serial`-Listen, Sperren und Sonden, Prüfung pro Welle, mit Demos und Selbsttest-Fragen.
- Lektion [L13 - Host firewall with nftables](../../../docs/lessons/L13-host-firewall-nftables.de.md): warum eine frische Verbindung der echte Test ist.
- Lektion [L10 - Compliance reporting](../../../docs/lessons/L10-compliance-reporting.de.md): woher der Bericht in der 5.01-Rolle kommt.

## Musterlösung

Anzeigen mit `lab solution 5.02`, anwenden mit `lab solve 5.02`.
