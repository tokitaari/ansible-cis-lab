# 4.10 - Paketsignaturen: jedes Repository geprüft, keine Umgehung

*[English](README.md)*

| Stufe | Schwierigkeit | Zeit | CIS-Bezug | Hosts |
|---|---|---|---|---|
| Stufe 4 - Fortgeschritten | ★★★★☆ | ~60 Min. | 1.2 Package management (L1) | `targets` |

**Konzepte:** `choice by pkg_mgr + assert`, `global switch vs per-repository value`, `reading the values in effect`, `set difference of file lists`, `ini_file sections`

## Ziel

Sorge dafür, dass jeder Paketmanager im Lab prüft, was er installiert: Kein Repository wird ohne eigenen Schlüssel vertraut, kein globaler Schalter schaltet die Prüfung ab, und das sagen die wirksamen Werte - nicht nur die Zeilen in deinen Dateien.

## Hintergrund

Jedes Target installiert Pakete über das Netz, und die Signaturprüfung unterscheidet ein echtes
Paket von einem gefälschten. Der Benchmark verlangt, dass diese Prüfung an ist und nur
Repositories mit bekanntem Schlüssel eingerichtet sind. Die Targets kommen mit einem "internen
Mirror", den ein früherer Admin auf die schnelle Art hinzugefügt hat - vertraut ohne Schlüssel. Es
ist ein lokales, leeres Repository, also bricht nichts, wenn es verschwindet, aber jeder
Paketmanager versteckt die Umgehung an einer anderen Stelle:

| `pkg_mgr` | Hosts | Wo die Prüfung geschaltet wird | Wo der Schlüssel eines Repositorys steht |
|---|---|---|---|
| `apt` | debian, ubuntu | `apt.conf.d` (`Acquire::AllowInsecureRepositories` ...), `trusted=yes` einer Quelle | `Signed-By` der Quelle |
| `dnf` | rocky, alma | `gpgcheck` in `[main]` von `dnf.conf` und je Repository | `gpgkey=` des Repositorys |
| `dnf5` | fedora | dieselben Schlüssel (`gpgcheck` ist ein Alias von `pkg_gpgcheck`) | `gpgkey=` |
| `zypper` | opensuse | `gpgcheck` in `[main]` von `zypp.conf` und je Repository | `gpgkey=` |
| `pacman` | arch | `SigLevel` in `[options]` und je Repository-Abschnitt | der pacman-Schlüsselbund (einer für alle) |
| `apk` | alpine | `/etc/apk/config` (`allow-untrusted`) | die Schlüssel in `/etc/apk/keys` (ein Satz für alle) |

Ein Wert im Repository gewinnt gegen den globalen, und ein Standardwert kann an sein, obwohl keine
Datei es sagt. Lektion L16 zeigt, wie jeder Manager die wirksamen Werte ausgibt; sieh dir die
Targets an, bevor du etwas schreibst.

## Anforderungen

- [ ] Die Daten je Manager kommen aus einem Dict mit `ansible_facts.pkg_mgr` als Schlüssel. Das Play bricht mit einer klaren Meldung ab auf einem Host, dessen Wert keiner der sechs oben ist.
- [ ] apt: Kein globaler Schalter erlaubt unsignierte oder unsichere Repositories (`apt-config dump` zeigt keinen auf true), und jeder Quelleneintrag - einzeilig oder deb822 - nennt mit `Signed-By` seinen eigenen Schlüssel und hat keine Option `trusted`/`allow-insecure`.
- [ ] dnf, dnf5, zypper: `gpgcheck=1` steht im Hauptabschnitt von `dnf.conf` bzw. `zypp.conf`, und jedes eingerichtete Repository, aktiviert oder nicht, prüft wirksam die Paketsignaturen und nennt einen `gpgkey`. zypper: Auch die Metadatenprüfung (`repo_gpgcheck`) ist an.
- [ ] pacman: Jedes Repository verlangt wirksam eine vertrauenswürdige Paketsignatur (sein eigenes `SigLevel` oder das globale, wenn es keines setzt).
- [ ] apk: kein `allow-untrusted` in den globalen Optionen, und jedes Repository ist eine `https://`-URL.
- [ ] Ein Repository, das sich nicht prüfen lässt - es hat keinen Schlüssel -, wird entfernt und nicht "repariert", indem du seine Prüfung einschaltest. Nach deinem Play gelingt eine Aktualisierung der Metadaten ohne Signaturwarnung (apt, dnf, zypper, apk). Zweiter Lauf: `changed=0`.

## Vorgehen

```bash
lab start 4.10            # legt /lab/work/4.10/ an
cd /lab/work/4.10
# playbook.yml schreiben, dann ausführen:
ansible-playbook playbook.yml
lab check 4.10            # prüft den Zustand und dass ein zweiter Lauf nichts ändert
```

Festgefahren? `lab hint 4.10 1` (sanft) ... `lab hint 4.10 3` (fast die Lösung).  
Bestanden? Lies `lab explain 4.10` - dort stehen Stolperfallen und Praxis-Hinweise.
Host kaputt? `./lab.sh reset <host>` auf dem Host stellt ihn wieder her.

## Bonus (optional)

- Schalte auf rocky die Metadatenprüfung von dnf ein (`repo_gpgcheck=1`) und führe `dnf makecache` aus. Was prüft sie, was `gpgcheck` nicht prüft, und was passiert mit einem Repository, das seine Metadaten nicht signiert?
- Installiere auf jeder Familie ein lokales Paket ohne Signatur (`dnf install ./x.rpm`, `pacman -U`, `apk add --allow-untrusted`). Welche Einstellungen (`localpkg_gpgcheck`, `LocalFileSigLevel`) entscheiden, und was sind ihre Standardwerte?
- Füge ein Fremd-Repository für apt richtig hinzu: sein Schlüssel in `/etc/apt/keyrings/`, mit `Signed-By` an diese eine Quelle gebunden (`ansible.builtin.deb822_repository`). Warum ist ein Schlüssel in `/etc/apt/trusted.gpg.d/` schlechter?
- Lade ein Paket herunter und prüfe es offline (`rpm -K`, `rpmkeys --checksig`). Welchen Schlüssel braucht es, und wo wird er importiert?
