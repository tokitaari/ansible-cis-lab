# 3.05 - Konten-Audit: UID 0, leere Passwörter, umask, TMOUT: Erklärung

### Was der Check prüft
`lab check 3.05` führt `check.yml` auf `targets` aus: Er zerlegt `/etc/passwd` und `/etc/shadow` und
prüft, dass `root` das einzige Konto mit UID 0 ist und kein Passwortfeld leer ist. In
`/etc/profile.d/50-cis-umask.sh` erwartet er eine Zeile, die auf `umask 0?27` passt; in
`50-cis-tmout.sh` ein `TMOUT=<n>` mit n ≤ 900 und eine Zeile, die mit `readonly TMOUT` beginnt.
Danach läuft dein Playbook noch einmal mit `--check` und muss `changed=0` melden.

Was er nicht prüft:

- `TMOUT=0` besteht, aber 0 schaltet den Timeout ab. `umask 0027` **fällt durch** (der reguläre
  Ausdruck erlaubt nur `027` oder `27`).
- Eigentümer und Modus der beiden Dateien, `export TMOUT`, und ob irgendeine Shell sie liest.
- Gesperrt oder gelöscht: Ein gelöschtes `guest` besteht ebenfalls.

### So funktioniert es

#### Erst aufklären, dann beheben
```yaml
- name: Find dangerous accounts
  ansible.builtin.set_fact:
    cis_uid0_extra: >-
      {{ (cis_account_files.results[0].content | b64decode).splitlines() | map('split', ':')
         | selectattr('2', 'equalto', '0') | map(attribute='0')
         | reject('equalto', 'root') | list }}
```
Jinja macht aus numerischen Attributnamen Listenindizes, `selectattr('2', ...)` filtert also nach
der UID-Spalte. Die Dateien selbst zu zerlegen funktioniert auf allen acht Systemen gleich (keine
`awk`-Dialekte). Gemessen in Lauf 1: `toor` auf debian und rocky gefunden, `guest` auf ubuntu und
fedora; Lauf 2 findet leere Listen, die Schleifen tun nichts (`changed=0`).

#### Die `userdel`-Falle
`userdel` weigert sich, ein Konto zu löschen, dessen UID einen laufenden Prozess besitzt; für UID 0
gilt das immer. Gemessen auf debian und rocky: `userdel toor` endet mit 8, `user toor is currently
used by process 1`. `force: true` (`userdel -f`) gibt dieselbe Zeile aus, löscht aber (Test in der
Session). `remove: true` muss aus bleiben: `userdel -r -f` auf einem UID-0-Alias entfernte dessen
Home-Verzeichnis, obwohl es root gehörte (Test in der Session mit einem Testverzeichnis). Das
`toor` im Lab hat `/nonexistent` als Home, ein echter Alias kann `/root` haben; nach der Lösung ist
`/root` unberührt (gemessen).

#### Sperren, nicht löschen
`password_lock: true` setzt `!` ins Passwortfeld (gemessen: `guest:!`). Sperren lässt sich
rückgängig machen, Löschen nicht; melde das Konto und lass einen Menschen entscheiden.

#### umask
`umask 027` gibt neuen Dateien `0640` und Verzeichnissen `0750`. Die Datei in `/etc/profile.d`
erreicht **Login-Shells**. Gemessen als neues Konto (`su -` und `<shell> -l -i -c`), bash und `sh`:

- vorher: `0002` auf debian und ubuntu, sonst `0022`;
- nachher: überall `0027`, mit einer Ausnahme: Auf alpine zeigte `su - -s /bin/bash -c` weiter
  `0022` (BusyBox-`su`; `sh` über dasselbe `su -` und `bash -l -i -c` ergaben `0027`; nicht
  untersucht).

Befehle, die Ansible ausführt, sind keine Login-Shells: Mit `become` behielten sie auf fünf Hosts
`0022`, auf rocky, alma und fedora zeigten sie nach der Übung aber `0027` (vorher `0022`). Deren
`/etc/bashrc` führt die `profile.d`-Schleife für Nicht-Login-Shells aus; der Weg vom SSH-Befehl
von Ansible dorthin wurde nicht verfolgt. Dort legen Tasks ohne ausdrückliches `mode:` strengere
Dateien an.

#### TMOUT und `readonly`
`TMOUT` ist eine Funktion der Shell. Gemessen mit einer untätigen Shell in einem Pseudo-Terminal
und `TMOUT=2` vor der Übung: bash beendete sich auf allen acht Hosts nach 2 s, BusyBox-`ash`
(alpine) auch, **dash nicht** - und dash ist `/bin/sh` auf debian und ubuntu, wo `useradd -D` neuen
Konten auch `/bin/sh` gibt. Dort setzt die Datei eine Variable, die niemand beachtet.

`readonly` verhindert `TMOUT=0` und `unset TMOUT` nur in dieser Shell: Das Attribut wird nicht
vererbt, eine Kind-`bash` kann den exportierten Wert entfernen (Test in der Session). Wird die
Datei in einer Shell zweimal eingelesen, erscheint `TMOUT: readonly variable` (Test in der
Session); keine der gemessenen Login-Shells tat das. Auf opensuse las auch eine interaktive
Nicht-Login-bash die Datei: Mit `TMOUT=2` in ihrer Umgebung lief sie nach der Übung weiter (vorher
nach 2 s beendet).

### Hinweise je Familie
| os_family | `/bin/sh` | Shell für `useradd` | Login-umask vorher → nachher | `TMOUT` in `/bin/sh` | umask von Ansible nachher (mit `become`) |
|---|---|---|---|---|---|
| Debian | dash | `/bin/sh` | `0002` → `0027` | nein | `0022` |
| RedHat | bash | `/bin/bash` | `0022` → `0027` | ja | `0027` |
| Suse | bash | `/bin/bash` | `0022` → `0027` | ja | `0022` |
| Alpine | BusyBox | `/bin/ash` | `0022` → `0027` (nicht über `su -` mit bash) | ja | `0022` |
| Archlinux | bash | `/usr/bin/bash` | `0022` → `0027` | ja | `0022` |

### Stolperfallen und gemessene Fakten
| Symptom | Ursache | Lösung |
|---|---|---|
| `user toor is currently used by process 1`, rc 8 | auch roots Prozesse haben UID 0 | `force: true`, nie mit `remove: true` |
| Der Check lehnt `umask 0027` ab | der Ausdruck akzeptiert nur `027` oder `27` | `umask 027` schreiben |
| `TMOUT` ist gesetzt, die Shell beendet sich nie | dash (`/bin/sh` auf Debian/Ubuntu) ignoriert es | Benutzern bash geben oder auf `ClientAlive*` von sshd setzen |
| `TMOUT: readonly variable` beim Login | die Datei wird zweimal eingelesen | nur einmal einlesen oder absichern |
| Ein Benutzer entfernt `TMOUT` in einer Unter-Shell | `readonly` wird nicht vererbt | erwartet; es schreckt ab, es kontrolliert nicht |
| Von Ansible angelegte Dateien sind auf Red-Hat-Hosts `0640` | `/etc/bashrc` wendet `profile.d` auf Nicht-Login-Shells an | an jedem Datei-Task `mode:` setzen |

### Praxis-Hinweise
- Lass die Aufklärung zuerst als eigenen Audit-Lauf laufen (4.01) und prüfe die Funde, bevor ein
  Play auf vielen Servern Konten löscht.
- Ein Timeout für untätige Shells schließt keine untätige SSH-Verbindung: Behalte `ClientAlive*`
  von sshd (2.02).
- Nutzer von zsh oder fish brauchen eigene Dateien; `/etc/profile.d/*.sh` lesen sh-kompatible
  Login-Shells.

### Weiterführend
- Lektion [L08 - Konten und PAM](../../../docs/lessons/L08-accounts-and-pam.de.md): Passwortfeld, UID 0, NSS, Login-Shells, `readonly`.
- Übung [2.02 - SSH-Server-Härtung mit Jinja2-Template](../../stage2-building-blocks/2.02-sshd-template/README.de.md)
- Übung [4.01 - Reiner Audit-Lauf mit Compliance-Bericht](../../stage4-advanced/4.01-audit-only-report/README.de.md)
- [`shadow(5)`](https://man.archlinux.org/man/shadow.5), [`useradd(8)`](https://man.archlinux.org/man/useradd.8)

## Musterlösung

Anzeigen mit `lab solution 3.05`, anwenden mit `lab solve 3.05`.
