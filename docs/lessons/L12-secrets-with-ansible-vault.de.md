# L12 - Geheimnisse mit Ansible Vault: ein Passwort aus Git und aus dem Log heraushalten

*[English](L12-secrets-with-ansible-vault.md)*

| Übungen | CIS-Abschnitte | Lesezeit | Baut auf |
|---|---|---|---|
| 4.04 | 5.2, 5.4.1 | ~30 Min. | L02, L04, L08 |

Automatisierung braucht Geheimnisse: das Passwort eines Notfallkontos, einen API-Token, einen
Schlüssel. Ein Playbook liegt in Git, seine Ausgabe in Terminals, Job-Logs und Tickets; ein
Geheimnis, das dort im Klartext steht, ist verloren. Ansible Vault verschlüsselt, was gespeichert
wird; `no_log` und ein paar Gewohnheiten halten es aus dem heraus, was ausgegeben wird; und ein
Passwort, das auf einem Host landet, muss so zu einem Hash werden, dass nicht jeder Lauf eine
Änderung ist. Diese Lektion behandelt die drei Bausteine und die Stellen, an denen jeder von ihnen
nicht mehr hilft.

## Lernziele

Nach dieser Lektion kannst du ...

- [ ] sagen, was Vault schützt (Daten im Ruhezustand im Repository) und Stellen nennen, an denen der Klartext trotzdem auftaucht
- [ ] Vault-Dateien ohne Editor anlegen, ansehen, ändern und neu verschlüsseln und die Wege nennen, das Vault-Passwort bereitzustellen
- [ ] zwischen einer verschlüsselten Datei und einem einzelnen verschlüsselten Wert wählen und Variablennamen auffindbar halten
- [ ] erklären, warum ein Hash mit zufälligem Salt eine Passwort-Task bei jedem Lauf `changed` melden lässt
- [ ] sagen, was ein fester Salt ändert, welche Regeln ein Salt einhalten muss und warum der Control-Node eine Rolle spielt
- [ ] vorhersagen, welche Ausgabe ein Geheimnis zeigt (`-v`, `--diff`, ein registriertes Ergebnis, `debug`), mit und ohne `no_log`
- [ ] `no_log` zum Debuggen abschalten, ohne die Task zu ändern
- [ ] die häufigen Vault-Fehler und die `ansible-lint`-Falle erkennen

## Theorie

### Wo ein Geheimnis durchsickert und was Vault abdeckt

Ein Geheimnis kann an drei Orten leben: im Repository, im Arbeitsspeicher, während ein Play
läuft, und in der Ausgabe. Vault schützt den ersten. Ein Passwort in `group_vars` steckt für immer
in jedem Klon und jedem alten Commit, denn das Löschen der Zeile löscht die Historie nicht. Vault
verschlüsselt die Datei, bevor sie committet wird; das Repository enthält dann Chiffretext, und wer
ihn lesen kann, aber das Vault-Passwort nicht kennt, erfährt nichts über den Inhalt.

Die beiden anderen Orte schützt es nicht. Während ein Play läuft, hält der Control-Node den
entschlüsselten Wert und gibt ihn an Module weiter, und ein Modul, dem ein Klartext-Passwort
übergeben wird, tut damit, was es eben tut. Die Ausgabe ist ein eigenes Problem: Ein Task-Ergebnis,
ein `--diff`, eine `debug`-Meldung oder ein Fehlertext kann den Wert in einem Terminal, einem
CI-Log oder einem AWX-Jobprotokoll ausgeben. Darum geht es im dritten Konzept dieser Lektion.
Zuerst die Mechanik.

### Vault: Dateien, Passwörter, IDs

Eine Vault-Datei ist eine Textdatei, deren erste Zeile ein Header ist und deren Rumpf aus
Hexadezimalzeichen besteht. Im Lab (ansible-core 2.21.6) lautet der Header
`$ANSIBLE_VAULT;1.1;AES256`. Die Chiffre ist AES-256 im Zählermodus mit einem HMAC-SHA256 über das
Ergebnis, und der Schlüssel wird mit PBKDF2 aus dem Vault-Passwort abgeleitet (gelesen aus
`ansible/parsing/vault/__init__.py` dieser Version). Zwei Folgen sind in der Praxis wichtig. Die
Datei lässt sich offline angreifen, wer sie hat; die Stärke des Geheimnisses ist also die Stärke
des Vault-Passworts. Und jede Verschlüsselung nutzt frische Zufallswerte, sodass derselbe Klartext
jedes Mal eine andere Datei ergibt.

`ansible-vault create` und `edit` öffnen `$EDITOR`, das am Schreibtisch passt, in einem Skript aber
nichts nützt. `encrypt` nimmt eine vorbereitete Datei; `view` und `decrypt` lesen sie zurück;
`rekey` ändert das Vault-Passwort. Lege ein Demo-Verzeichnis an und probiere es aus (die Passwörter
sind erfunden und nur für diese Lektion):

```bash
mkdir -p /tmp/lesson12 && cd /tmp/lesson12
printf 'lesson-only-password\n' > .vault-pass
chmod 600 .vault-pass
printf 'vault_lesson12_token: tok-4711\n' > secrets.yml
ansible-vault encrypt --vault-password-file .vault-pass secrets.yml
head -n 1 secrets.yml
ansible-vault view --vault-password-file .vault-pass secrets.yml
```

Das Vault-Passwort kann aus drei Quellen kommen: `--vault-password-file` (oder die
Umgebungsvariable `ANSIBLE_VAULT_PASSWORD_FILE`, die auch `ansible-lint` braucht, siehe
Stolperfallen), einer Eingabeaufforderung (`--ask-vault-pass`) oder einem Programm. Ist die Datei
hinter `--vault-password-file` ausführbar, startet Ansible sie und nimmt ihre Standardausgabe als
Passwort - getestet mit einem Shell-Skript aus zwei Zeilen. Das ist der Einhängepunkt für einen
Secret-Store: Das Skript fragt ihn und gibt die Antwort aus, und es liegt keine Passwortdatei auf
der Platte. Ein abschließender Zeilenumbruch oder CRLF in einer Passwortdatei wird ignoriert
(getestet), und Ansible warnt nicht, wenn die Datei für andere lesbar ist (getestet mit Modus
0644); setze also selbst `chmod` und halte sie mit einem Eintrag in `.gitignore` aus dem
Repository. Das Lab macht das für das ganze Verzeichnis `work/` bereits.

Dass derselbe Inhalt zweimal verschlüsselt verschieden ausfällt, zeigt die zweite Eigenschaft:

```bash
printf 'x: 1\n' > a.yml && cp a.yml b.yml
ansible-vault encrypt --vault-password-file .vault-pass a.yml b.yml
cmp a.yml b.yml || echo "different files for the same content"
```

Für Git heißt das: Wer ein unverändertes Geheimnis neu verschlüsselt, schreibt den ganzen Rumpf neu,
und der Diff zeigt eine Änderung, die keine ist. `ansible-vault edit` ist sanfter, als es klingt -
den Editor ohne Änderung zu verlassen, ließ die Datei Byte für Byte gleich (getestet mit
`EDITOR=true`) -, aber `encrypt`, `decrypt` mit anschließendem `encrypt` und `rekey` schreiben
immer neuen Inhalt.

**Vault-IDs.** Verschiedene Geheimnisse können verschiedene Passwörter haben: eins für die
Entwicklung, eins für die Produktion. `--vault-id dev@.dev-pass` verschlüsselt mit diesem Passwort
und schreibt das Label in den Header (`$ANSIBLE_VAULT;1.2;AES256;dev`). Ein Play, das Dateien mit
zwei Labels lädt, braucht beide `--vault-id`-Optionen. Mit nur einer bricht es an der ersten Datei
ab, die es nicht öffnen kann, mit `Decryption failed (no vault secrets were found that could
decrypt)`. Dieselbe Meldung kommt bei einem falschen Passwort; ganz ohne Passwortquelle lautet sie
`Attempting to decrypt but no vault secrets found`.

**Eine ganze Datei oder ein Wert.** `ansible-vault encrypt_string` verschlüsselt einen einzelnen
Wert und gibt ihn als `!vault |`-Block aus, der in einer sonst lesbaren Variablendatei stehen kann.
Dann bleibt der Variablenname in Diffs und in `grep` lesbar, der Block ist aber unhandlich zu
prüfen und von Hand zu rotieren. Eine vollständig verschlüsselte Datei verbirgt jeden Namen darin,
und die Frage „Wo wird dieses Geheimnis benutzt?" lässt sich schwer beantworten. Die übliche
Konvention löst das: Die Geheimnisse liegen in einer verschlüsselten Datei unter Namen, die mit
`vault_` beginnen, und der Rest des Projekts bekommt lesbare Variablen, die darauf zeigen.
`group_vars` kann ein Verzeichnis sein; Ansible lädt jede Datei darin und entschlüsselt die
verschlüsselten dabei (getestet):

```bash
mkdir -p group_vars/all
printf 'lesson12_token: "{{ vault_lesson12_token }}"\n' > group_vars/all/vars.yml
cp secrets.yml group_vars/all/vault.yml
grep -rn vault_lesson12_token group_vars
```

Der `grep` findet die eine Stelle, die beide Namen verbindet, ohne etwas zu entschlüsseln. Ein Play
benutzt dann nur den lesbaren Namen:

```yaml
- name: Use the indirection
  hosts: targets
  gather_facts: false
  tasks:
    - name: Show that the value arrived without printing it
      ansible.builtin.debug:
        msg: "the token has {{ lesson12_token | length }} characters"
```

Speichere es als `/tmp/lesson12/gv.yml` und führe `ansible-playbook gv.yml --vault-password-file
.vault-pass` aus: Die Gruppenvariablen neben dem Playbook werden geladen, und das Play gibt
`8 characters` aus. Ohne Passwortquelle bricht dasselbe Play vor der ersten Task ab, mit
`Attempting to decrypt but no vault secrets found`. Verschlüsselte Dateien werden auch entschlüsselt,
wenn ein Play sie mit `vars_files` oder `-e @file` lädt (beides getestet).

### Ein Passwort hashen: Salt und Idempotenz

Die meisten Module, die auf einem Host ein Passwort setzen, erwarten einen Hash, nicht das
Passwort (das Format `$id$salt$hash` aus L08). Der Filter `password_hash` macht auf dem
Control-Node aus einem Klartext einen solchen Hash, und das Modul vergleicht die *Zeichenkette* mit
dem Gespeicherten. Daraus entsteht ein klassisches Problem. Ein Salt ist eine Eingabe des Hashs;
wird keiner angegeben, entsteht bei jedem Aufruf ein neuer zufälliger, und der Filter liefert für
dasselbe Passwort jedes Mal eine andere Zeichenkette. Das Modul sieht bei jedem Lauf einen
Unterschied, meldet `changed` und schreibt einen neuen Hash - eine Änderung in `/etc/shadow` ohne
Grund. Mit dem Demo-Konto unten sieht man es:

```yaml
- name: Salt and idempotency
  hosts: targets
  gather_facts: false
  become: true
  vars_files:
    - secrets.yml
  vars:
    lesson12_salt: null
  tasks:
    - name: Create a demo account with a hashed password
      ansible.builtin.user:
        name: lesson12
        shell: /bin/sh
        create_home: false
        password: "{{ vault_lesson12_token | password_hash('sha512', lesson12_salt) }}"
```

Speichere es als `/tmp/lesson12/hash.yml` und führe es aus:

```bash
ansible-playbook hash.yml --vault-password-file .vault-pass          # geändert
ansible-playbook hash.yml --vault-password-file .vault-pass          # wieder geändert
ansible-playbook hash.yml --vault-password-file .vault-pass -e lesson12_salt=demosalt1234
ansible-playbook hash.yml --vault-password-file .vault-pass -e lesson12_salt=demosalt1234
```

Auf dem Session-Host meldeten drei Läufe ohne Salt hintereinander jeweils `changed=1`. Mit festem
Salt ändert der erste Lauf den Hash einmal, der nächste meldet `changed=0`, und `--check` danach
ebenso. Das Demo-Konto bleibt zurück: Entferne es mit `userdel lesson12` (das `user`-Modul mit
`state: absent` tut dasselbe) oder `./lab.sh reset <host>`.

Ein stabiler Hash braucht also einen Salt, den du kontrollierst. Vier Punkte gehören dazu:

- **Die Regeln.** Ein SHA-512-Salt hat höchstens 16 Zeichen aus `./0-9A-Za-z`. Ein längerer
  scheitert mit `invalid salt size supplied (20), expected at most 16`, einer mit einem anderen
  Zeichen mit `invalid characters in salt` (beides getestet).
- **Der Algorithmus.** Der Filter akzeptiert `md5`, `blowfish`, `sha256` und `sha512`; `yescrypt`,
  der Standard mehrerer Lab-Hosts (L08), wird mit `yescrypt is not in the list of supported passlib
  algorithms: md5, blowfish, sha256, sha512` abgelehnt. Das Ergebnis beginnt mit
  `$6$rounds=656000$`: Die Rundenzahl ist Teil der Zeichenkette (bei `rounds=5000` fiel das Feld
  weg).
- **Die Entscheidung.** Woher kommt der Salt? Eine Konstante für das ganze Inventar bedeutet: Zwei
  Hosts mit demselben Passwort haben denselben Hash, was jedem, der beide `shadow`-Dateien liest,
  die Wiederverwendung zeigt und eine vorberechnete Tabelle für alle Hosts nutzbar macht. Ein Salt,
  der pro Host verschieden, aber aus etwas Stabilem abgeleitet ist, bleibt wiederholbar und
  vermeidet das. Wie du ihn ableitest, ist dein Entwurf; er muss ein gültiger Salt sein und darf
  sich zwischen Läufen nicht ändern.
- **Der Control-Node.** In ansible-core 2.21.6 benutzt `password_hash` die libxcrypt-Bibliothek des
  Control-Nodes, wenn sie vorhanden ist (`-vv` gibt `Using CryptHash to hash input with
  'sha512_crypt'` aus), und passlib nur als Rückfall. Mit libxcrypt ist der übergebene Salt nur
  Ausgangsmaterial, aus dem die Bibliothek den Salt macht, den sie schreibt: Aus der Eingabe
  `demosalt1234` wurde im Hash `YJKPjBLMgFLA`. Der passlib-Weg schreibt die Eingabe unverändert in
  den Hash, derselbe Aufruf liefert dort also eine andere Zeichenkette (getestet, indem in einer
  Python-Sitzung der Weg abgeschaltet wurde). Innerhalb eines Control-Nodes ist der Hash stabil; der
  Control-Container des Labs und der Session-Host lieferten für die Demo-Eingabe dieselbe
  Zeichenkette. Wer das Playbook auf einem anderen Control-Node ausführt, muss beim ersten Mal mit
  einem `changed` pro Host rechnen.

Ein zweiter Weg, die Änderungen zu stoppen, ist `update_password: on_create`; das `user`-Modul setzt
das Passwort dann nur, wenn das Konto angelegt wird. Es funktioniert (getestet: `changed=1`, dann
`0` mit zufälligem Salt), stoppt aber auch alles andere: Wird das Geheimnis im Vault rotiert,
meldet der Lauf `changed=0`, und der alte Hash bleibt auf dem Host. Eine Passwort-Task, die eine
Rotation nicht bemerkt, verdeckt Abweichungen - das Gegenteil dessen, wofür ein Härtungslauf da
ist.

### no_log: was es verbirgt und was nicht

Viele Tasks geben ihr Ergebnis aus. Eine Task, die ein Geheimnis anfasst, muss dafür sorgen, dass es
nicht darin steht, und dafür gibt es zwei Schichten. Die erste ist das Modul: Es erklärt, welche
seiner Argumente sensibel sind, und maskiert sie im Ergebnis. Von den getesteten Modulen maskiert
`user` das `password` (das Ergebnis zeigt `"password": "NOT_LOGGING_PASSWORD"`, und weder Hash noch
Klartext tauchten in `-v`, `-vvv`, `--diff` oder in der Ausgabe einer fehlschlagenden Task auf), und
`copy` maskiert `content`. Die zweite Schicht ist das Task-Schlüsselwort `no_log: true`, das das
ganze Ergebnis verbirgt. Es zählt überall dort, wo ein Geheimnis kein Argument ist, das das Modul
kennt: in einer Kommandozeile, in einem `copy`, das mit `--diff` angezeigt wird, in einer Variable,
die eine spätere Task ausgibt. Das Play unten legt ein Geheimnis an vier solche Stellen, nach einer Vorbereitungs-Task für
das Verzeichnis (die Targets sind eigene Hosts, und `copy` legt keine Elternverzeichnisse an). Das
Zurücklesen wird im Check-Modus übersprungen, weil die Datei dann noch nicht existiert:

```yaml
- name: Where does a secret show up?
  hosts: targets
  gather_facts: false
  vars_files:
    - secrets.yml
  tasks:
    - name: Make sure the demo directory exists
      ansible.builtin.file:
        path: /tmp/lesson12
        state: directory
        mode: "0755"
      # Vorbereitung der Demo, nicht Teil der Lektion
      check_mode: false

    - name: Write a config file with the secret
      ansible.builtin.copy:
        dest: /tmp/lesson12/plain.conf
        content: "token={{ vault_lesson12_token }}\n"
        mode: "0600"

    - name: Write the same file with no_log
      ansible.builtin.copy:
        dest: /tmp/lesson12/hidden.conf
        content: "token={{ vault_lesson12_token }}\n"
        mode: "0600"
      no_log: true

    - name: Read the hidden file back
      ansible.builtin.command: cat /tmp/lesson12/hidden.conf
      register: lesson12_read
      changed_when: false
      no_log: true
      when: not ansible_check_mode

    - name: Print what the registered result holds
      ansible.builtin.debug:
        msg: "{{ lesson12_read.stdout }}"
      when: not ansible_check_mode
```

Speichere es als `/tmp/lesson12/leak.yml` und führe es mit `--diff` aus (ein zweiter Lauf meldet
`changed=0`):

```bash
ansible-playbook leak.yml --vault-password-file .vault-pass --diff
```

Die erste Task zeigt das Geheimnis in ihrem Diff als `+token=tok-4711`, obwohl das Modul `copy` den
Inhalt im Ergebnis maskiert: Bei `-v` und `-vvv` tauchte das Geheimnis nicht auf. Die zweite Task
gibt weder Diff noch Ergebnis aus (`no_log` unterdrückt auch den Diff; `diff: false` an der Task
tut das für den Diff allein). Die letzte Task gibt das Geheimnis aus, und das ist der Kern der
Lektion: `no_log` hindert *diese* Task am Ausgeben, aber die registrierte Variable enthält den Wert
weiter, und alles, was sie später liest, darf ihn zeigen. Dasselbe gilt für `ansible-inventory
--list` (es gab den entschlüsselten Wert einer verschlüsselten Gruppenvariable aus) und für `debug`
mit `var:`. Gib nicht aus, was du aus einer Task mit Geheimnis registriert hast, und registriere es
nur, wenn die nächste Task es braucht.

Drei weitere Einzelheiten. In einer Schleife verbirgt `no_log` auch das Element: Das Label wird zu
`(censored due to no_log)`. Ein Fehler in einer `no_log`-Task wird ohne Ursache gemeldet, nur
`Module failed: The command exited with a non-zero return code.`, sodass sich eine kaputte Task
schwer debuggen lässt. Und eine Kommandozeile geben Module aus, die sie zurückmelden: Ein `command`
mit dem Geheimnis im Argument zeigte es bei `-v` und in seiner Fehlermeldung. Der übliche
Kompromiss ist eine Variable, die entscheidet:

```yaml
- name: no_log that can be switched off
  hosts: targets
  gather_facts: false
  vars_files:
    - secrets.yml
  vars:
    lesson12_show: false
  tasks:
    - name: Run a command that fails, with the secret on its command line
      ansible.builtin.command: "false {{ vault_lesson12_token }}"
      changed_when: false
      ignore_errors: true
      no_log: "{{ not (lesson12_show | bool) }}"
```

Speichere es als `/tmp/lesson12/nolog.yml`. Der Standardlauf gibt für den Fehler eine
`censored`-Meldung aus; `-e lesson12_show=true` gibt den Befehl aus, einschließlich `tok-4711`.
Benutze die zweite Form nur auf einem Wegwerf-Host und nie in der CI. Einen globalen Schalter gibt
es (`ANSIBLE_NO_LOG=true`; der Diff von `leak.yml` zeigte damit kein Geheimnis), er verbirgt aber
die Details jeder Task, auch die, die du lesen willst; das Schlüsselwort mit einer Variable
entscheidet pro Task. Alle diese Ergebnisse stammen aus ansible-core 2.21.6; welche
Modulargumente maskiert werden, entscheidet jedes Modul selbst und kann bei anderen Modulen oder in
anderen Versionen abweichen, also sieh dir die Ausgabe eines Testlaufs an, bevor du dich darauf
verlässt.

## CIS-Hintergrund

Ein Notfallkonto (Break-Glass-Konto) existiert für den Tag, an dem SSO oder das Automatisierungskonto
nicht funktionieren, und es ist deshalb das Konto, das ohne alles andere funktionieren muss. Das
macht es nützlich und gefährlich zugleich: Es ist ein dauerhafter lokaler Administrator. Der Katalog
des Labs enthält keine Empfehlung, die ein solches Konto verlangt; die Empfehlungen verlangen, dass
jedes vorhandene Konto denselben Regeln folgt. Passwortalterung und starkes Hashing für lokale
Konten sind 5.4.1 im [Kontrollkatalog](../../cis/controls.yml) (L08 behandelt, was die Werte
bedeuten und woher sie kommen). Rechteausweitung über sudo, mit Protokollierung und mit eingeschalteter
erneuter Authentifizierung, ist 5.2 (L03 erklärt die sudoers-Dateien).

Der Umgang mit dem Geheimnis ist kein Benchmark-Thema, entscheidet aber, ob die Benchmark-Einstellungen
etwas bedeuten. Ein Scanner liest den `shadow`-Eintrag und sieht ein Algorithmus-Präfix und ein paar
Zahlen; er kann nicht erkennen, dass das Passwort hinter dem Hash in einem öffentlichen Repository
liegt. Die Praktiken dieser Lektion schließen diese Lücke: das Geheimnis in einer verschlüsselten
Datei, das Vault-Passwort getrennt vom Repository aufbewahrt, ein Log, das es nicht enthält, und ein
stabiler Hash, damit der Lauf, der die Einstellung durchsetzt, den Host nicht selbst jedes Mal
ändert. Für ein Notfallkonto kommt dazu, was Automatisierung nicht für dich tut: jede Anmeldung damit
überwachen und sein Passwort nach der Benutzung rotieren.

## Plattformunterschiede

Die Plattformunterschiede dieses Themas liegen auf dem Control-Node und bei den Konto-Werkzeugen.
Die Zeilen nutzen die eigenen Fakten der Hosts; die Spalte *Standard-Hash* wiederholt die
Messungen aus L08.

| os_family | Hosts | Konto-Werkzeuge | Minimales Passwortalter | Standard-Hash für neue Passwörter |
|---|---|---|---|---|
| Debian | debian, ubuntu | shadow `useradd`, `chage` | unterstützt | YESCRYPT in `login.defs` |
| RedHat | rocky, alma, fedora | shadow `useradd`, `chage` | unterstützt | YESCRYPT in `login.defs` |
| Suse | opensuse | shadow `useradd`, `chage` | unterstützt | SHA512 in `/usr/etc/login.defs` |
| Alpine | alpine | shadow `useradd`, `usermod`, `chage` im Lab-Image; `adduser` ist BusyBox | unterstützt | keine `ENCRYPT_METHOD`-Zeile |
| Archlinux | arch | shadow `useradd`, `chage` | mit shadow 4.20 entfernt (`chage --help` listet kein `--mindays`) | YESCRYPT in `login.defs` |

Auf alpine nahm das `user`-Modul `password_expire_max` an, und `chage -l` zeigte es (gemessen mit
dem Lab-Image nach 0.02). Übung 4.04 lässt Alpine trotzdem aus; der Übungstext nennt dafür seinen
eigenen Grund.

### In den Lab-Containern

- Der Control-Container baut auf `python:3.13-slim-trixie` auf; `password_hash` nutzt dort
  libxcrypt, also gilt die erste der beiden oben beschriebenen Salt-Behandlungen.
- Das Vault-Passwort einer Übung liegt in `work/`, das Git ignoriert. Trage in deinem eigenen
  Repository den Dateinamen vor dem ersten Commit in `.gitignore` ein; ein späterer Eintrag lässt
  sie in der Historie.
- Die Demo-Konten und -Dateien dieser Lektion liegen auf den Targets oder in `/tmp/lesson12` auf
  dem Control-Node. `./lab.sh reset <host>` entfernt die Konten (unter Windows `.\lab.ps1 reset
  <host>`).
- Nichts hier braucht ein Kernel-Feature, das den Containern fehlt (siehe
  [Container-Grenzen](../CONTAINER_LIMITS.de.md)).

## Stolperfallen

| Symptom | Ursache | Lösung |
|---|---|---|
| Eine Passwort-Task ist bei jedem Lauf `changed` | der Hash wird jedes Mal mit zufälligem Salt gebildet | dem Filter einen gültigen, wiederholbaren Salt geben; siehe die Salt-Regeln |
| `Attempting to decrypt but no vault secrets found` | das Play lädt eine verschlüsselte Datei, und es wurde keine Passwortquelle angegeben | `--vault-password-file`, `ANSIBLE_VAULT_PASSWORD_FILE` oder `--ask-vault-pass` |
| `Decryption failed (no vault secrets were found that could decrypt)` | falsches Passwort, oder eine Datei mit Label, zu dem die `--vault-id` fehlt | das Passwort verwenden, mit dem die Datei verschlüsselt wurde; jede `--vault-id` angeben, die das Play braucht |
| `ansible-lint` meldet `internal-error` für `ansible-playbook --syntax-check` | die Syntaxprüfung lädt die verschlüsselte Datei und hat kein Passwort | vor dem Linten `ANSIBLE_VAULT_PASSWORD_FILE` setzen (damit lief ein Lint durch) |
| Das Geheimnis erscheint in der `--diff`-Ausgabe | ein Datei-Modul zeigt den neuen Inhalt | `no_log: true`, oder `diff: false` nur für den Diff |
| Eine spätere Task gibt ein Geheimnis aus, das die frühere verborgen hat | die registrierte Variable enthält den Wert weiter | nicht ausgeben; nicht registrieren, wenn es nicht nötig ist |
| `invalid salt size supplied (20), expected at most 16` oder `invalid characters in salt` | der Salt verletzt die Regeln des Algorithmus | für SHA-512 höchstens 16 Zeichen aus `./0-9A-Za-z` |
| `yescrypt is not in the list of supported passlib algorithms` | der Filter bietet den Algorithmus nicht an | `sha512` benutzen |
| Jeder Host ist einmal `changed`, nachdem das Playbook auf eine andere Maschine gewandert ist | der andere Control-Node hasht denselben Salt anders | eine Änderung hinnehmen und den Control-Node einheitlich halten |
| Der Diff einer Vault-Datei ändert sich, obwohl das Geheimnis gleich blieb | jede Verschlüsselung nutzt neue Zufallswerte | nur verschlüsseln, wenn sich der Inhalt ändert |

## Übungen

| Übung | Was diese Lektion vorbereitet |
|---|---|
| [4.04](../../exercises/stage4-advanced/4.04-vault-break-glass-account/README.de.md) | eine verschlüsselte Variablendatei, ein wiederholbarer Passwort-Hash, Geheimnisse aus der Ausgabe heraushalten |

Starte sie mit `lab start 4.04`; `lab show 4.04` gibt ihr README aus.

## Selbstkontrolle

1. Was schützt Ansible Vault, und wo erscheint ein verschlüsseltes Geheimnis trotzdem im Klartext?

   <details><summary>Antwort</summary>

   Es schützt die Datei im Repository: Wer den Chiffretext, aber nicht das Vault-Passwort hat,
   erfährt nichts. Der Klartext existiert während eines Plays im Speicher des Control-Nodes, wird an
   Module übergeben und kann von Task-Ergebnissen, `--diff`, `debug` und Fehlermeldungen
   ausgegeben werden.

   </details>

2. Du verschlüsselst dieselbe Datei zweimal, und die beiden Ergebnisse unterscheiden sich. Was folgt
   daraus für Git, und bedeutet ein geänderter Chiffretext, dass sich das Geheimnis geändert hat?

   <details><summary>Antwort</summary>

   Jede Verschlüsselung nutzt frische Zufallswerte, der Rumpf ändert sich also auch bei gleichem
   Inhalt, und ein Diff der Datei beweist nichts über das Geheimnis. Verschlüssele nur neu, wenn
   sich der Inhalt wirklich ändert, und lies die Änderung mit `ansible-vault view` oder durch
   Vergleich der entschlüsselten Werte.

   </details>

3. Eine Task, die ein Passwort setzt, meldet bei jedem Lauf `changed`. Was ist die Ursache, und was
   kostet `update_password: on_create` im Vergleich zur Behebung der Ursache?

   <details><summary>Antwort</summary>

   `password_hash` ohne Salt erfindet bei jedem Aufruf einen neuen, die Zeichenkette ist also
   jedes Mal anders, obwohl das Passwort gleich ist. `on_create` lässt die Task `changed=0` melden,
   ändert aber auch nie ein vorhandenes Passwort: Eine Rotation im Vault wird ignoriert, und der
   alte Hash bleibt. Ein wiederholbarer Salt bewahrt Idempotenz und Rotation.

   </details>

4. Ein Salt mit 20 Zeichen scheitert. Nachdem das Playbook von einer anderen Maschine läuft, meldet
   jeder Host eine Änderung. Erkläre beides.

   <details><summary>Antwort</summary>

   Ein SHA-512-Salt hat höchstens 16 Zeichen aus `./0-9A-Za-z`. Der zweite Fall kommt vom
   Control-Node: Mit libxcrypt ist der übergebene Salt nur Ausgangsmaterial, mit dem
   passlib-Rückfall wird er unverändert in den Hash geschrieben, derselbe Aufruf liefert also eine
   andere Zeichenkette. Innerhalb eines Control-Nodes ist der Hash stabil; zwischen Control-Nodes
   ist das nicht gesichert.

   </details>

5. Eine `copy`-Task schreibt ein Geheimnis in eine Datei. Zeigt `-v` es? Zeigt es `--diff`? Was
   ändert `no_log: true`, und was kann es danach noch zeigen?

   <details><summary>Antwort</summary>

   `copy` maskiert `content` im Ergebnis, `-v` zeigt es also nicht, aber `--diff` gibt den neuen
   Inhalt aus. `no_log: true` unterdrückt den Diff und das Ergebnis dieser Task. Eine Variable, die
   aus einer Task registriert wurde, die das Geheimnis gelesen hat, enthält es weiter, und ein
   späteres `debug` kann es ausgeben.

   </details>

6. Warum wird `no_log` in manchen Projekten über eine Variable gesetzt, und warum lässt man es in
   einem Entwicklungslauf nicht einfach weg?

   <details><summary>Antwort</summary>

   Eine `no_log`-Task verbirgt den Grund ihres eigenen Fehlschlags, was das Debuggen erschwert. Mit
   einer Variable kann ein Entwickler es auf einem Wegwerf-Host mit `-e` abschalten, ohne die Task zu
   ändern. Es standardmäßig wegzulassen, würde Geheimnisse in Logs bringen, der sichere Wert ist
   deshalb der Standard.

   </details>

7. `ansible-lint` scheitert an einem Playbook mit verschlüsselten `vars_files`, obwohl das Playbook
   läuft. Was fehlt, und welche zwei Wege gibt es, Namen so zu ordnen, dass `grep` die Verwendung
   eines Geheimnisses findet?

   <details><summary>Antwort</summary>

   Die Syntaxprüfung des Linters lädt die verschlüsselte Datei und hat kein Vault-Passwort;
   `ANSIBLE_VAULT_PASSWORD_FILE` zu setzen behebt es. Um Namen auffindbar zu halten, lässt man
   entweder die Variablennamen lesbar und verschlüsselt nur die Werte mit `encrypt_string`, oder
   man hält die Geheimnisse in einer verschlüsselten Datei mit Namen `vault_*` und verweist aus
   lesbaren Variablen einer zweiten Datei darauf.

   </details>

## Weiterführendes

- [Protecting sensitive data with Ansible vault](https://docs.ansible.com/ansible/latest/vault_guide/index.html) - der Vault-Leitfaden: IDs, `encrypt_string`, Passwortquellen
- [ansible-vault](https://docs.ansible.com/ansible/latest/cli/ansible-vault.html) - jeder Unterbefehl und jede Option
- [password_hash filter](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/password_hash_filter.html) - Algorithmen, `salt`, `rounds`
- [Protecting sensitive data with no_log](https://docs.ansible.com/ansible/latest/reference_appendices/logging.html#protecting-sensitive-data-with-no-log) - was das Schlüsselwort verbirgt und was nicht
- [`crypt(5)`](https://man.archlinux.org/man/crypt.5) - die Hash-Formate und die Bedeutung von `$id$`, Salt und Rounds
- [Glossar](../GLOSSARY.de.md) - Begriffe dieser Lektion: `no_log`, salt, Vault
