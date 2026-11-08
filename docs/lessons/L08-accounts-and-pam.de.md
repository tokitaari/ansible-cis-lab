# L08 - Konten und PAM: wer sich anmelden darf, wie und mit welchem Passwort

*[English](L08-accounts-and-pam.md)*

| Übungen | CIS-Abschnitte | Lesezeit | Baut auf |
|---|---|---|---|
| 3.02, 3.03, 3.05, 4.06 | 5.3.2, 5.3.3, 5.4.1, 5.4.2, 5.4.3 | ~30 Min. | L02, L03, L04 |

Jede Anmeldung endet in zwei Fragen: Welches Konto ist das, und darf es herein? Linux beantwortet
sie mit ein paar Textdateien und einem Stapel kleiner Module namens PAM. Die Antworten zu härten
heißt, diese Dateien richtig zu lesen, zu wissen, welche Vorgaben welche Konten erreichen, und
einen Stack zu ändern, den oft ein Werkzeug für dich schreibt. Diese Lektion behandelt die
Konten-Datenbanken, Alterung und Hashing, wie PAM-Stacks aufgebaut sind, die beiden Module, die
die Übungen konfigurieren, und warum nichts davon in der Shell auftaucht, die Ansible benutzt.

## Lernziele

Nach dieser Lektion kannst du ...

- [ ] einen `passwd`- und einen `shadow`-Eintrag lesen und sagen, was `x`, `*`, `!` und ein leeres Feld bedeuten
- [ ] erklären, warum die UID wichtiger ist als der Name `root` und warum `getent` und eine Datei sich widersprechen können
- [ ] sagen, welche Alterungswerte eine Vorgabe in `login.defs` erreicht und welche nicht
- [ ] den Hash-Algorithmus am Präfix eines Hashes erkennen und die zwei Stellen finden, die ihn wählen
- [ ] eine PAM-Regel (Typ, Control, Modul) lesen und vorhersagen, was `required`, `requisite` und `sufficient` tun
- [ ] erklären, warum von Hand bearbeitete PAM-Dateien verloren gehen, und den Generator jeder Familie nennen
- [ ] beschreiben, was `pam_pwquality` und `pam_faillock` prüfen, wann und was sie unberührt lassen
- [ ] sagen, warum `umask` und `TMOUT` aus einem Profil-Skript für eine Ansible-Task unsichtbar sind

## Theorie

### Konten-Datenbanken: passwd, shadow und was das Passwortfeld sagt

Ein Linux-Konto ist eine Zeile in einer Textdatei. `/etc/passwd` hat sieben durch Doppelpunkte
getrennte Felder: Name, Passwort-Platzhalter, UID, GID, Kommentar, Home-Verzeichnis, Shell. Die
Datei ist für alle lesbar, also steht das Passwort nicht darin: Das zweite Feld ist `x`, ein
Verweis auf `/etc/shadow`. Diese Datei kann nur root lesen und enthält pro Konto: Name,
Passwortfeld, Tag der letzten Änderung (Tage seit 1970-01-01), Mindestalter, Höchstalter,
Warnfrist, Inaktivitätsfrist, Ablauftag und ein reserviertes Feld.

Das Passwortfeld ist das, worauf Audits schauen:

| Wert | Bedeutung |
|---|---|
| `$id$salt$hash` | ein Passwort-Hash; die `id` nennt den Algorithmus (nächstes Konzept) |
| beginnt mit `!` | gesperrt: der Hash bleibt erhalten, aber kein Passwort passt; ein einzelnes `!` ist gesperrt ohne Hash |
| `*` | es kann nie ein Passwort passen - typisch für Systemkonten |
| leer | **gar kein Passwort**; das Konto ist nicht gesperrt |

Ein leeres Feld ist wegen `pam_unix` gefährlich: Laut Handbuch wird ein leeres Passwort abgelehnt,
solange die Option `nullok` nicht gesetzt ist, und die `password`-Zeilen von `pam_unix` tragen
`nullok` auf opensuse, fedora, rocky, alma und arch (mit `grep` gemessen). Die Audit-Frage lautet
"ist das Feld leer?", nicht "verzeiht der Stack es gerade?".

Der Name `root` ist eine Konvention. Der Kernel entscheidet nach der **UID**: Jedes Konto mit UID 0
hat die Rechte von root, egal wie es heißt. "Wer ist hier root?" beantwortet das dritte Feld von
`passwd`, nicht das erste.

Konten lassen sich aus zwei Quellen lesen, die sich widersprechen können. Ein Datei-Parser sieht
die Datei auf diesem Host. `getent` fragt den Name Service Switch (NSS), der die Dateien *und*
alles andere befragt, wofür der Host eingerichtet ist (LDAP, SSSD, ...). Für ein Audit der lokalen
Datenbanken liest du die Dateien; für "wer kann sich hier überhaupt anmelden" fragst du `getent`.
Das Modul `ansible.builtin.getent` legt die Antwort als Fact ab:

```yaml
- name: Which accounts have a real login shell?
  hosts: targets
  gather_facts: false
  tasks:
    - name: Read the passwd database through NSS
      ansible.builtin.getent:
        database: passwd
    - name: Accounts whose shell is not a no-login shell
      vars:
        no_login: [/sbin/nologin, /usr/sbin/nologin, /usr/bin/nologin, /bin/false, /bin/sync, /sbin/halt, /sbin/shutdown]
        rows: "{{ ansible_facts.getent_passwd | dict2items | rejectattr('value.5', 'in', no_login) | list }}"
      ansible.builtin.debug:
        msg: "{{ rows | map(attribute='key') | zip(rows | map(attribute='value.1'), rows | map(attribute='value.5')) | map('join', ' ') | list }}"
```

`getent_passwd` bildet jeden Namen auf die Liste `[x, UID, GID, Kommentar, Home, Shell]` ab, also
ist `value.1` die UID und `value.5` die Shell. Auf dem Ubuntu-24.04-Host, auf dem ich getestet
habe, listet das Play vier Konten (root, ubuntu, postgres, claude), jedes mit `/bin/bash`. Der
Pfad einer No-Login-Shell unterscheidet sich je Distribution, deshalb nennt das Play alle.

### Alterung, Hashing und woher Vorgaben kommen

**Alterung** sind die Zahlen im `shadow`-Eintrag: Mindest- und Höchstalter des Passworts, die
Warnfrist und die Inaktivitätsfrist, nach der ein abgelaufenes Konto gesperrt wird. `chage -l
<user>` gibt sie aus. Neue Konten bekommen sie aus `/etc/login.defs` (`PASS_MAX_DAYS`,
`PASS_MIN_DAYS`, `PASS_WARN_AGE`); die Vorgabe für Inaktivität kommt aus `useradd -D`. Das
Schlüsselwort ist *neu*: Die Werte werden beim Anlegen in das Konto kopiert. Mit `useradd` auf dem
Session-Host getestet: Nachdem `PASS_MAX_DAYS` auf 365 gesetzt war, hatte ein danach angelegtes
Konto 365, das zuvor angelegte behielt 99999. Eine geänderte Vorgabe sichert nur künftige Konten;
bestehende behalten ihre Werte, bis `chage` (oder das Modul `user`) sie ändert.

```yaml
- name: Where do a new account's aging values come from?
  hosts: targets
  become: true
  gather_facts: false
  tasks:
    - name: Create a demo account without a password
      ansible.builtin.user:
        name: lesson08
        shell: /bin/sh
        create_home: false
    - name: Read its aging values
      ansible.builtin.command: chage -l lesson08
      register: aging
      changed_when: false
      when: not ansible_check_mode
    - name: Read the defaults of the shadow tools
      ansible.builtin.command: grep -h -E '^[[:space:]]*PASS_(MAX|MIN|WARN)' /etc/login.defs /usr/etc/login.defs
      register: defs
      changed_when: false
      failed_when: defs.rc > 2
      check_mode: false
    - name: Compare both
      ansible.builtin.debug:
        msg:
          account: "{{ aging.stdout_lines | default([]) | select('match', '(Minimum|Maximum|Number of days)') | list }}"
          login_defs: "{{ defs.stdout_lines }}"
      when: not ansible_check_mode
```

Das Demo-Konto bleibt zurück: Entferne es mit `userdel lesson08` oder `./lab.sh reset <host>`
(unter Windows `.\lab.ps1 reset <host>`). `grep` endet mit 2, wenn eine seiner Dateien fehlt, gibt
aber die Treffer der anderen aus; deshalb akzeptiert das Play Rückgabecodes bis 2. Auf dem
Ubuntu-Host zeigen beide Abschnitte 99999, 0 und 7. Lass es auf allen acht Hosts laufen und achte
darauf, welche der beiden Dateien die Werte enthält und was `chage -l` auf arch ausgibt.

**Hashing.** Ein Hash in `shadow` beginnt mit `$id$`; die id nennt den Algorithmus (mit `crypt(3)`
auf dem Session-Host geprüft):

| Präfix | Algorithmus | Hinweis |
|---|---|---|
| `$1$` | MD5 | veraltet |
| `$5$` | SHA-256 | |
| `$6$` | SHA-512 | langjähriger Standard |
| `$y$` | yescrypt | neuer; auf hohen Speicherbedarf ausgelegt, daher kostet massenhaftes Raten auf GPUs mehr als gegen SHA-512 |

Am Präfix kannst du eine bestehende Datenbank prüfen, ohne ein Passwort zu kennen. Ein Hash wird
nur neu geschrieben, wenn sein Besitzer das Passwort ändert; ein stärkeres Verfahren schützt also
*künftige* Passwörter, alte Hashes behalten ihr Präfix.

Zwei Stellen wählen das Verfahren für ein neues Passwort. `ENCRYPT_METHOD` in `login.defs` lesen
die shadow-Werkzeuge, und laut Handbuch von `pam_unix` stammt dessen Standard-Hash daher. Die
`pam_unix`-Zeile des `password`-Stacks kann außerdem selbst einen Algorithmus nennen. Die
Lab-Hosts unterscheiden sich (Tabelle unten): debian, ubuntu und die Red-Hat-Familie nennen
`yescrypt` in der Zeile, arch und opensuse nennen nichts; `login.defs` sagt überall YESCRYPT außer
auf opensuse (SHA512) und alpine (keine `ENCRYPT_METHOD`-Zeile). Ein Verfahren, das nur an einer
Stelle gesetzt wird oder schwächer ist als das, was der Host schon nutzt, geht leicht schief, und
ein Scanner, der beide Werte akzeptiert, sagt es dir nicht.

**Vendor-Split.** Manche Distributionen halten ihre Vorgaben unter `/usr/etc` und lesen aus `/etc`
nur die Überschreibungen des Administrators, damit Updates Vendor-Dateien ersetzen können, ohne
deine Änderungen anzufassen. Auf opensuse im Lab gibt es `/etc/login.defs` nicht: Die Werte stehen
in `/usr/etc/login.defs`, und ein Verzeichnis `/etc/login.defs.d` existiert. Die Regel gilt
allgemein: Bevor du eine Datei in `/etc` anlegst, prüfe, wie das Programm seine Konfiguration
findet - eine Task "anlegen, falls es fehlt" kann die ganze Vendor-Vorgabe durch die paar Zeilen
ersetzen, die du geschrieben hast.

**Funktionen, die verschwinden.** `shadow` 4.20 hat das *Mindest*alter des Passworts als
Sicherheitsproblem entfernt. Auf dem arch-Host nennt `chage --help` kein `--mindays` (`grep -c`: 0
Treffer, gegen 1 auf den anderen sieben); eine Task, die das Mindestalter setzt, hat dort nichts
aufzurufen. Die robuste Gewohnheit ist die aus L04: Frage, was der Host kann, statt den Namen der
Distribution zu prüfen.

### PAM: Typen, Controls und wer den Stack schreibt

PAM (Pluggable Authentication Modules) trennt *Programme*, die authentifizieren, von den *Regeln*,
die sagen, wie. Braucht `sshd`, `su` oder `passwd` eine Entscheidung, ruft es die PAM-Bibliothek
mit seinem **Dienstnamen** auf, und die Bibliothek liest `/etc/pam.d/<service>`. Jede Zeile, die
kein Kommentar ist, ist eine Regel `type control module arguments`.

Der **Typ** nennt die Frage:

- `auth` - ist dieser Benutzer, wer er vorgibt zu sein? (prüft das Passwort, vergibt Credentials)
- `account` - darf dieses Konto den Dienst jetzt nutzen? (abgelaufen, gesperrt, falsche Zeit)
- `password` - der Benutzer ändert das Geheimnis: prüfen und speichern
- `session` - baut auf und ab, was die Sitzung braucht (Protokoll, Limits, Mounts)

Das **Control** sagt, was das Ergebnis des Moduls für den ganzen Stack bedeutet (`pam.conf(5)`):

| Control | Ein Fehlschlag des Moduls | Ein Erfolg |
|---|---|---|
| `required` | lässt den Stack scheitern, aber die übrigen Module laufen noch | nötig, nicht ausreichend |
| `requisite` | lässt den Stack sofort scheitern und kehrt zur Anwendung zurück | nötig, nicht ausreichend |
| `sufficient` | wird ignoriert | beendet den Stack mit Erfolg, wenn kein früheres `required`-Modul scheiterte |
| `optional` | zählt nur, wenn es das einzige Modul dieses Typs ist | ebenso |
| `include` / `substack` | - | holen die Regeln dieses Typs aus einer anderen Datei; ein `substack` zählt als eine Einheit |

Die Klammerform `[success=1 default=ignore]` sagt dasselbe je Rückgabewert; diese hier heißt "bei
Erfolg die nächste Regel überspringen". Regeln laufen von oben nach unten, also ist die
**Reihenfolge Teil der Bedeutung**: Ein `sufficient`-Modul vor einer Prüfung kann die Prüfung
unerreichbar machen.

Woher kommen diese Dateien? Oft nicht von dir. Die meisten Familien haben einen Generator, der die
Dateien, die jeder Dienst einbindet, aus kleinen Profilen baut: `pam-auth-update` (Debian-Familie),
`authselect` (Red-Hat-Familie), `pam-config` (SUSE). Die Befehle gibt es auf genau diesen Hosts
(`command -v` auf allen acht; keiner der drei auf alpine und arch). Eine generierte Datei sagt das:
Auf Ubuntu 24.04 nennen alle fünf `common-*`-Dateien `pam-auth-update` in ihrem Text, und das
nächste Paket, das das Werkzeug aufruft, schreibt sie neu. Eine von Hand bearbeitete Zeile in so
einer Datei ist keine Konfiguration, sondern ein Countdown. Nutze den Mechanismus des Generators
(ein Profil, ein Feature) und lass ihn neu erzeugen. Dieses Play listet pro Host die PAM-Dateien,
die symbolische Links sind, und die, die einen Generator nennen:

```yaml
- name: Who maintains the PAM files of this host?
  hosts: targets
  become: true
  gather_facts: false
  tasks:
    - name: PAM files that are symbolic links
      ansible.builtin.find:
        paths: /etc/pam.d
        file_type: link
      register: pam_links
    - name: PAM files that name a generator in their text
      ansible.builtin.find:
        paths: /etc/pam.d
        file_type: file
        contains: '.*(authselect|pam-auth-update|pam-config)'
      register: pam_generated
    - name: Show both lists
      ansible.builtin.debug:
        msg:
          links: "{{ pam_links.files | map(attribute='path') | map('basename') | sort }}"
          generated: "{{ pam_generated.files | map(attribute='path') | map('basename') | sort }}"
```

`find` wendet `contains` ab dem Zeilenanfang an, daher das führende `.*`. Auf Ubuntu ist das
Ergebnis die fünf `common-*`-Dateien und keine Links; ich habe es nur dort ausgeführt, lass es also
auf den anderen Hosts laufen und vergleiche mit den Generatoren oben.

PAM unterscheidet sich in einem Punkt von anderer Härtung: **Ein Fehler sperrt alle aus, deine
Automatisierung eingeschlossen.** Die Gewohnheiten aus L02 gelten (kleine Schritte, `--limit`, ein
Backup dessen, was du änderst), dazu eine eigene: Halte eine zweite Root-Sitzung offen, während du
einen Stack änderst, und mache den ersten Test zu einer Anmeldung von einem anderen Terminal.

### Zwei Module im Stack: pwquality und faillock

**`pam_pwquality`** ist ein Modul vom Typ `password` (der einzige Typ, den es anbietet): Es läuft,
wenn jemand über ein Programm mit PAM-Stack ein Passwort ändert, und beurteilt das *neue*
Passwort; bestehende werden nie nachgeprüft. Seine Einstellungen stehen in
`/etc/security/pwquality.conf` und in den `*.conf`-Dateien von `/etc/security/pwquality.conf.d`,
gelesen in ASCII-Reihenfolge, wobei der spätere Wert gewinnt (`pwquality.conf(5)` von libpwquality
1.4.5) - der Grund für das numerische Präfix in Drop-in-Namen: `50-site.conf` schlägt
`10-vendor.conf`.

Es prüft, mit den Standardwerten des Handbuchs: eine Mindestlänge (`minlen`, 8), Zeichenklassen
(`minclass` zählt, wie viele von Ziffern, Großbuchstaben, Kleinbuchstaben und Sonstigen
vorkommen müssen, Standard 0; oder je Klasse mit `dcredit`, `ucredit`, `lcredit`, `ocredit`, wobei
eine *negative* Zahl "mindestens so viele" heißt und eine positive ein Bonus auf die Länge ist),
Wiederholungen (`maxrepeat`), monotone Folgen (`maxsequence`) - beide bei 0 aus - und eine
Wörterbuchprüfung (`dictcheck`, an). Eine Vorgabe zählt für die Härtung am meisten:
**`enforce_for_root` ist aus**. Setzt root ein Passwort, das die Prüfungen nicht besteht, bekommt
root nur eine Meldung und die Änderung geht durch; eine Richtlinie, die root ausnimmt, hat ein Loch
genau dort, wo das wertvollste Passwort liegt.

**`pam_faillock`** zählt fehlgeschlagene Anmeldungen je Konto und sperrt das Konto nach zu vielen.
Das Modul steht im `auth`-Stack an bis zu drei Stellen - `preauth` vor der Passwortabfrage,
`authfail` und `authsucc` nach dem Urteil - und einmal in `account` (`pam_faillock(8)`). Die Zähler
sind eine Datei je Benutzer in einem Tally-Verzeichnis, standardmäßig `/var/run/faillock`, das ein
Neustart normalerweise leert. Die Einstellungen stehen in `/etc/security/faillock.conf`
(`faillock.conf(5)` von Linux-PAM 1.5.3): `deny` (Standard 3), `fail_interval` (900 s, das
Zeitfenster, in dem Fehlversuche zählen), `unlock_time` (600 s; **0 heißt nie** - gesperrt, bis
jemand zurücksetzt) und `even_deny_root` (aus, root wird also standardmäßig nicht gesperrt). Das
Handbuch warnt außerdem, dass dauerhaftes Sperren bekannte Benutzernamen zum Ziel eines
Denial-of-Service macht. Das Werkzeug `faillock --user <name>` zeigt einen Zähler, `--reset` löscht
ihn:

```yaml
- name: What has pam_faillock counted so far?
  hosts: targets
  become: true
  gather_facts: false
  tasks:
    - name: Read the tally of root
      ansible.builtin.command: faillock --user root
      register: tally
      changed_when: false
      check_mode: false
    - name: List the tally files
      ansible.builtin.find:
        paths: /var/run/faillock
        file_type: file
      register: tally_files
      check_mode: false
    - name: Show the result
      ansible.builtin.debug:
        msg:
          faillock: "{{ tally.stdout_lines }}"
          tally_files: "{{ tally_files.files | map(attribute='path') | list }}"
```

Auf dem Ubuntu-Host besteht die Ausgabe aus der Kopfzeile (`When Type Source Valid`) und nichts
Gezähltem. "Lesen" hat einen Nebeneffekt: `faillock --user root` legt für dieses Konto eine leere
Tally-Datei an (ein Name, den es nicht gibt, legt nichts an; getestet) - harmlos, aber kein reines
Lesen. Das Modul und das Werkzeug sind auf allen acht Hosts installiert, alpine eingeschlossen, aber
vor jeder Übung verweist nur auf arch ein Stack auf das Modul (`system-auth`).

Die **Aussperr-Analyse** gehört vor jede Änderung, die Anmeldungen abweisen kann. Die Frage ist
nicht "welche Anmeldungen zählen als fehlgeschlagen", sondern "welche *meiner* Anmeldungen laufen
durch die PAM-Typen, in denen das Modul steht". Das hängt davon ab, wie der Dienst PAM nutzt: Lies
den Stack des Dienstes, lies, was die eigene Konfiguration des Dienstes zu PAM sagt (`UsePAM yes`
auf den sieben systemd-Hosts; auf alpine habe ich in `sshd_config` keine `UsePAM`-Zeile gefunden
und nicht geprüft, was sein `sshd` ohne sie tut), und teste mit einem Ersatzkonto, während eine
zweite Sitzung offen ist.

### Login-Shells: wo umask und TMOUT wohnen

Zwei Shell-Einstellungen tauchen in Härtungsleitfäden auf: die `umask` (welche Rechtebits neue
Dateien *verlieren*; eine umask von 022 macht aus dem Standardmodus 666 den Modus 644) und `TMOUT`
(eine untätige interaktive `bash` beendet sich nach so vielen Sekunden). Es sind Shell-Builtins und
Variablen, keine Kernel- oder PAM-Einstellungen, sie gelten also dort, wo eine Shell sie setzt. Der
übliche Ort ist ein Skript in `/etc/profile.d`, das `/etc/profile` für **Login-Shells** einliest.
Auf Ubuntu durchläuft `/etc/profile` die Dateien `/etc/profile.d/*.sh`, der Name muss also auf
`.sh` enden; auf allen acht Hosts erwähnt `/etc/profile` `profile.d` (`grep -c`; wie jede Schleife
Dateien auswählt, habe ich nicht gelesen).

Für Ansible heißt das: Eine Task läuft in einer Shell, in der sich niemand angemeldet hat, also ist
das, was ein Profil-Skript setzt, **nicht da**. Ein Härtungs-Play kann richtig sein, und jede Task,
die die Umgebung über `command` oder `shell` prüft, zeigt trotzdem den alten Wert. Frage gezielt
eine Login-Shell:

```yaml
- name: Does a login shell see something that Ansible does not?
  hosts: targets
  gather_facts: false
  tasks:
    - name: Ask a login shell
      ansible.builtin.command: bash -lc 'echo "umask=$(umask) TMOUT=${TMOUT-unset}"'
      register: login_shell
      changed_when: false
      check_mode: false
    - name: Ask the shell Ansible uses for its own commands
      ansible.builtin.shell: echo "umask=$(umask) TMOUT=${TMOUT-unset}"
      register: plain_shell
      changed_when: false
      check_mode: false
    - name: Compare
      ansible.builtin.debug:
        msg:
          login_shell: "{{ login_shell.stdout }}"
          ansible_shell: "{{ plain_shell.stdout }}"
```

Auf dem Ubuntu-Host lauten beide Zeilen `umask=0022 TMOUT=unset`: Dort setzt nichts die Werte. Lass
das Play nach 3.05 noch einmal laufen: Die erste Zeile ändert sich. Verlass dich nicht darauf, dass
die zweite bleibt, wie sie war: Auf rocky, alma und fedora zeigten Befehle, die Ansible mit `become`
ausführte, nach 3.05 ebenfalls `umask=0027` (die EXPLANATION von 3.05 enthält die Messung).

`readonly` verhindert, dass ein Benutzer den Timeout wieder abschaltet. Eine schreibgeschützte
Variable verweigert Zuweisung und `unset`:

```bash
bash -c 'readonly TMOUT=900; (TMOUT=1); echo "assign rc=$?"; unset TMOUT; echo "unset rc=$?"; echo "TMOUT=$TMOUT"'
```

Bash meldet `TMOUT: readonly variable` und `cannot unset: readonly variable`, beide Rückgabecodes
sind 1 und der Wert bleibt 900. Zwei Grenzen: Diese Einstellungen erreichen nur Shells, die das
Profil lesen, und ein Idle-Timeout in der Shell hilft nicht gegen eine Verbindung, die einfach
offen bleibt - dafür sind die eigenen Einstellungen des SSH-Daemons zuständig.

## CIS-Hintergrund

Die fünf Abschnitte des [Kontrollkatalogs](../../cis/controls.yml) hinter dieser Lektion sind alle
Level 1:

- **5.4.1** (Shadow-Passwort-Suite): wie lange ein Passwort lebt, der Hash, der es schützt, wann
  sich ein ungenutztes Konto selbst sperrt - es verkürzt das Fenster, in dem ein gestohlener Hash
  oder ein vergessenes Konto nützlich ist.
- **5.4.2 und 5.4.3** (root, Systemkonten, Umgebung): genau eine UID 0, kein Konto mit leerem
  Passwort, sichere Shell-Vorgaben. Die ersten beiden sind *erst Audit*: herausfinden, was da ist,
  dann ändern.
- **5.3.2 und 5.3.3** (PAM): Konten nach wiederholten Fehlversuchen sperren und eine
  Passwortrichtlinie durchsetzen, die root einschließt. Beide ändern den PAM-Stack, wo ein falscher
  Schritt in einer Aussperrung endet.

Benchmarks nummerieren das unterschiedlich (L01); die Katalog-IDs sind die des Labs. Der Katalog
markiert alle fünf mit `container: full`: Die PAM-Stacks, `shadow`-Werkzeuge und Shells im Lab sind
die echten.

Die Abwägungen sind betrieblich. Konten zu sperren ist selbst ein Angriff - wer einen Benutzernamen
kennt, kann ihn sperren -, deshalb ist root standardmäßig ausgenommen, ist `unlock_time` eine
Entscheidung und brauchen Dienstkonten Überlegung. Eine zu strenge Richtlinie führt zu Passwörtern
auf Notizzetteln. Keines der beiden Argumente hebt die Kontrolle auf; sie bestimmen die Zahlen und
die Ausnahmen, und eine Ausnahme wird dokumentiert, nicht weggelassen (L01).

## Plattformunterschiede

| os_family | Hosts | PAM-Generator | `login.defs` | `ENCRYPT_METHOD` | `pam_unix`-Passwortzeile | `pam_pwquality` | `pam_faillock` Modul / in einem Stack |
|---|---|---|---|---|---|---|---|
| Debian | debian (13), ubuntu (26.04) | `pam-auth-update` | `/etc/login.defs` | YESCRYPT | nennt `yescrypt` | nicht installiert | vorhanden / in keinem Stack |
| RedHat | rocky (10.2), alma (10.2), fedora (44) | `authselect` | `/etc/login.defs` | YESCRYPT | nennt `yescrypt`, `nullok` | installiert, in `system-auth` und `password-auth` | vorhanden / in keinem Stack |
| Suse | opensuse (Leap 16.0) | `pam-config` | `/usr/etc/login.defs`; keine in `/etc`, aber `/etc/login.defs.d` existiert | SHA512 | nennt keinen Algorithmus, `nullok` | nicht installiert | vorhanden / in keinem Stack |
| Alpine | alpine (3.24) | keiner gefunden | `/etc/login.defs`, keine `ENCRYPT_METHOD`-Zeile | - | keine solche Zeile in `/etc/pam.d` gefunden | nicht installiert | vorhanden / in keinem Stack |
| Archlinux | arch | keiner gefunden | `/etc/login.defs` | YESCRYPT | nennt keinen Algorithmus, `nullok` | nicht installiert | vorhanden / in `system-auth` |

Alle Werte wurden auf den Targets des Labs gemessen (`grep`, `command -v`, `find`). `chage --help`
nennt `--mindays` auf jedem Host außer arch. Alpine hat `/etc/pam.d` und bringt das PAM-Modul
`faillock` mit, "Alpine hat kein PAM" ist also zu stark; welche seiner Dienste PAM tatsächlich
nutzen, habe ich nicht geprüft, ebenso nicht, ob sein `/etc/login.defs` überhaupt eine
`PASS_*`-Zeile hat.

### In den Lab-Containern

- PAM, die `shadow`-Werkzeuge und die Shells sind echt; die Konten- und PAM-Übungen verhalten sich
  wie auf einer VM (siehe [die Container-Grenzen](../CONTAINER_LIMITS.de.md)). Eine Konsolen-Anmeldung
  kann das Lab nicht zeigen, teste eine Sperre also mit `su` oder `ssh` von einem anderen Terminal.
- Das Tally-Verzeichnis liegt im Container: `./lab.sh reset <host>` setzt es zusammen mit jedem
  Demo-Konto und jeder Demo-Datei auf den Startzustand zurück.
- Die Beispiele setzen voraus, dass 0.02 erledigt ist (alpine braucht Python). `chage` und
  `faillock` gibt es auf allen acht Hosts; das erste und das letzte Beispiel brauchen zusätzlich
  `getent` und `bash` - fehlt eines davon auf alpine, ist dieses Werkzeug der Grund für einen Fehler,
  nicht dein Play.

## Stolperfallen

| Symptom | Ursache | Lösung |
|---|---|---|
| Neue Konten haben die neuen Alterungswerte, alte nicht | `login.defs` wird beim Anlegen eines Kontos kopiert | bestehende Konten mit `chage` oder dem Modul `user` ändern |
| Du hast `ENCRYPT_METHOD` geändert und neue Passwörter nutzen trotzdem ein anderes Verfahren | die `pam_unix`-Zeile des `password`-Stacks nennt selbst einen Algorithmus; `login.defs` ist nur die Vorgabe | beide Stellen ansehen |
| Eine Task, die das Mindestalter setzt, scheitert auf arch | `shadow` 4.20 hat die Funktion entfernt | die Fähigkeit erkennen, nie den Distro-Namen prüfen |
| Eine neue `/etc/login.defs` erscheint und die Vendor-Werte sind weg | ein Host mit Vendor-Split liest seine Vorgaben aus `/usr/etc` | vor dem Anlegen prüfen, wo das Programm sucht |
| Deine Änderung an `/etc/pam.d/common-password` verschwindet | `pam-auth-update` (oder `authselect`, `pam-config`) erzeugt sie neu | Profil oder Feature ändern, nicht die generierte Datei |
| Root setzt ein schwaches Passwort und nichts hält es auf | `enforce_for_root` ist standardmäßig aus | im Drop-in setzen |
| Ein Drop-in in `pwquality.conf.d` wirkt nicht | eine spätere Datei setzt dieselbe Option | die letzte Datei in ASCII-Reihenfolge gewinnt |
| Ein Konto sperrt sich nach ein paar Test-Anmeldungen | der Tally zählt jeden Fehlversuch innerhalb von `fail_interval` | `faillock --user <name> --reset`; mit einem Ersatzkonto testen |
| `getent passwd` zeigt Konten, die nicht in `/etc/passwd` stehen | NSS ergänzt Verzeichnisdienste | entscheiden, welche Frage das Audit stellt, und die passende Quelle lesen |
| `TMOUT` ist gesetzt, aber `command: echo $TMOUT` zeigt nichts | Tasks laufen nicht in einer Login-Shell | mit `bash -lc` prüfen oder die Datei lesen |

## Übungen

| Übung | Worauf diese Lektion vorbereitet |
|---|---|
| [3.02](../../exercises/stage3-intermediate/3.02-password-aging/README.de.md) | was die Alterungsfelder und `login.defs`-Vorgaben erreichen, wie Hashes benannt sind, wo Vorgaben auf einem Host mit Vendor-Split liegen |
| [3.03](../../exercises/stage3-intermediate/3.03-password-quality/README.de.md) | der Typ `password`, Drop-in-Reihenfolge, was `pam_pwquality` prüft, wer den Stack jeder Familie schreibt |
| [3.05](../../exercises/stage3-intermediate/3.05-accounts-and-environment/README.de.md) | was Passwortfeld und UID bedeuten, NSS gegenüber Dateien, Login-Shells und `readonly` |
| [4.06](../../exercises/stage4-advanced/4.06-faillock-authselect/README.de.md) | die Typen `auth` und `account`, Controls, Tally und `faillock.conf`, Aussperr-Analyse |

Starte eine Übung mit `lab start <id>`; `lab show <id>` gibt ihre README aus.

## Selbstkontrolle

1. Warum schaut ein Audit auf "wer ist root" in das dritte Feld von `passwd`, und wann liefert
   `getent passwd` eine andere Liste als die Datei?

   <details><summary>Antwort</summary>

   Der Kernel entscheidet nach der UID, also hat jedes Konto mit UID 0 die Rechte von root, egal wie
   es heißt. `getent` fragt NSS, das auf dem Host eingerichtete Verzeichnisdienste einschließt
   (LDAP, SSSD, ...); die Datei listet nur lokale Konten. Für ein lokales Audit liest du die Datei,
   für "wer kann sich hier anmelden" fragst du `getent`.

   </details>

2. Du änderst `PASS_MAX_DAYS` in `login.defs` auf 365. Was passiert mit einem Konto, das schon
   existiert, und was mit einem, das du danach anlegst? Wie prüfst du es?

   <details><summary>Antwort</summary>

   Das bestehende Konto behält seinen Wert: Die Vorgabe wird beim Anlegen in das Konto kopiert. Ein
   neues Konto bekommt 365. `chage -l <user>` gibt die eigenen Werte des Kontos aus; vergleiche sie
   mit der Datei.

   </details>

3. Ein Härtungs-Play schreibt auf jedem Host `ENCRYPT_METHOD SHA512` in `login.defs`, ohne den Host
   vorher anzusehen. Was kann schiefgehen, und wie erkennst du den Algorithmus bestehender Hashes?

   <details><summary>Antwort</summary>

   Ein Host, der schon ein stärkeres Verfahren nutzt, bekommt eine schwächere Vorgabe für neue
   Passwörter, und ein Scanner, der beide Werte akzeptiert, meldet nichts. Bestehende Hashes zeigen
   ihren Algorithmus am Präfix: `$6$` SHA-512, `$y$` yescrypt, `$5$` SHA-256, `$1$` MD5. Prüfe außerdem,
   ob die `pam_unix`-Zeile selbst einen Algorithmus nennt.

   </details>

4. Ein Stack hat zwei `required`-Module für `auth` und das erste scheitert. Läuft das zweite? Was
   ändert sich, wenn das erste `requisite` ist? Warum ist eine von Hand bearbeitete Zeile in einer
   generierten PAM-Datei keine gute Idee?

   <details><summary>Antwort</summary>

   Bei `required` läuft das zweite Modul noch und der Stack scheitert am Ende; bei `requisite` kehrt
   der Stack sofort zurück. Eine generierte Datei (`pam-auth-update`, `authselect`, `pam-config`) wird
   beim nächsten Lauf des Werkzeugs neu geschrieben, die Änderung geht verloren: Füge ein Profil oder
   Feature hinzu, das der Generator kennt, und lass ihn neu erzeugen.

   </details>

5. Zwei Drop-ins definieren `minlen`: `10-vendor.conf` sagt 8, `50-site.conf` sagt 14. Welcher Wert
   gilt, und was passiert, wenn root ein Passwort mit 10 Zeichen setzt, während `enforce_for_root`
   nicht gesetzt ist?

   <details><summary>Antwort</summary>

   14 gilt: Die Dateien werden in ASCII-Reihenfolge gelesen und der spätere Wert gewinnt. Ohne
   `enforce_for_root` bekommt root eine Meldung über die gescheiterte Prüfung, aber die Änderung geht
   durch.

   </details>

6. `unlock_time` ist `0` und `deploy` ist nach Fehlversuchen gesperrt. Wann ist es wieder nutzbar,
   und warum ist dauerhaftes Sperren riskant? Ein Play setzt `TMOUT` in einem Profil-Skript und prüft
   es mit `command: echo "$TMOUT"` - warum scheitert die Prüfung?

   <details><summary>Antwort</summary>

   Erst nachdem jemand den Tally löscht (`faillock --user deploy --reset`) oder nach einem Neustart,
   wenn das Tally-Verzeichnis beim Booten geleert wird. Wer den Benutzernamen kennt, kann das Konto
   durch Fehlversuche sperren - ein Denial-of-Service. Die Prüfung scheitert, weil das Modul `command`
   nicht in einer Login-Shell läuft, das Profil-Skript also nie gelesen wird; frage gezielt eine
   Login-Shell (`bash -lc 'echo $TMOUT'`) oder prüfe die Datei.

   </details>

## Weiterführendes

- [`ansible.builtin.getent`](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/getent_module.html), [`ansible.builtin.user`](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/user_module.html) und [`ansible.builtin.find`](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/find_module.html) - die Module der Beispiele
- [`shadow(5)`](https://man.archlinux.org/man/shadow.5) und [`login.defs(5)`](https://man.archlinux.org/man/login.defs.5) - die Felder und die Vorgaben
- [`chage(1)`](https://man.archlinux.org/man/chage.1) und [`useradd(8)`](https://man.archlinux.org/man/useradd.8) - Werte je Konto und Vorgaben
- [`pam.conf(5)`](https://man.archlinux.org/man/pam.conf.5) und [`pam_unix(8)`](https://man.archlinux.org/man/pam_unix.8) - Regelsyntax, Controls, Hash-Optionen
- [`pwquality.conf(5)`](https://man.archlinux.org/man/pwquality.conf.5) und [`pam_pwquality(8)`](https://man.archlinux.org/man/pam_pwquality.8) - Einstellungen zur Passwortqualität
- [`faillock.conf(5)`](https://man.archlinux.org/man/faillock.conf.5), [`pam_faillock(8)`](https://man.archlinux.org/man/pam_faillock.8) und [`faillock(8)`](https://man.archlinux.org/man/faillock.8) - das Sperrmodul und sein Werkzeug
- [Glossar](../GLOSSARY.de.md) - Begriffe dieser Lektion: authselect, faillock, `login.defs`, PAM,
  pwquality, shadow, `TMOUT`, `umask`
