# 4.04 - Ansible Vault: Notfall-Admin-Konto: Erklärung

### Was der Check prüft
`lab check 4.04` führt `check.yml` aus, danach dein Playbook noch einmal mit `--check`, und
erwartet `changed=0`. Der zweite Lauf braucht das Vault-Passwort, also gib `--vault-password-file`
an `lab check` mit. `check.yml` hat zwei Plays:
- Auf dem Control-Node muss `vault.yml` mit `$ANSIBLE_VAULT` beginnen. Der Inhalt wird nicht
  gelesen; eine Klartextdatei fällt durch.
- Auf jedem Target außer Alpine liest er `/etc/shadow` und `/etc/sudoers.d/60-cisadmin`. Der
  Eintrag `cisadmin` braucht einen Hash, der mit `$6$` oder `$y$` beginnt, ein Höchstalter von
  365 und ein Mindestalter von mindestens 1 (nur wo `chage --help` noch `--mindays` nennt). Die
  sudoers-Datei braucht die Regel `cisadmin ALL=(ALL) ALL` und kein `NOPASSWD`.

Der Check meldet sich nie als `cisadmin` an und kann das Passwort daher nicht beurteilen. Er
prüft auch `no_log` nicht - diese Anforderung hältst du selbst ein.

### So funktioniert es

#### Vault-Grundlagen
```bash
ansible-vault create  --vault-password-file .vault-pass vault.yml
ansible-vault view    --vault-password-file .vault-pass vault.yml
ansible-vault rekey   ...    # neues Vault-Passwort
ansible-playbook playbook.yml --vault-password-file .vault-pass
```
Konvention: Geheimnisse heißen `vault_*` und werden aus normalen Variablen referenziert
(`cisadmin_password: "{{ vault_cisadmin_password }}"`), damit `grep` findet, wo Geheimnisse
genutzt werden, ohne etwas zu entschlüsseln.

#### Warum das Salt zählt
`password_hash('sha512')` ohne Salt-Argument zieht bei jedem Aufruf ein Zufallssalt: jeder Lauf
ein anderer Hash, jedes Mal `changed`, und jeder Lauf ersetzt ein Passwort, das ein Mensch
gesetzt haben könnte. Ein Salt aus dem Hostnamen liefert pro Lauf denselben Hash und auf
verschiedenen Hosts verschiedene Hashes, ein geknackter Hash verrät also keine
Wiederverwendung. Die Lösung nimmt 16 Zeichen des SHA-256 des Hostnamens, das Maximum, das ein
SHA-512-Salt fasst.

Das Salt ist nicht die ganze Eingabe. Der Filter reicht es an ein Backend auf dem Control-Node
weiter: libxcrypt (der Control-Node des Labs) oder passlib. Dasselbe Salt kommt von beiden als
**anderer** String zurück - gemessen: das Literal-Salt `demosalt1234` ergab bei libxcrypt
`YJKPjBLMgFLA`, passlib behielt es unverändert. Jedes Backend ist für sich stabil, zwischen
den Läufen ändert sich also nichts. Ein neues Control-Node-Image, ein geänderter Pin oder ein
anderes Python kann das Backend aber wechseln, und dann meldet jeder Host einmal `changed` für
den neuen Hash-String. Das Passwort selbst bleibt gleich.

#### no_log
Das `user`-Modul maskiert `password` in seiner eigenen Ausgabe (`NOT_LOGGING_PASSWORD`).
Gemessen mit ansible-core 2.21.6: weder `-v`, `-vvv`, `--diff` noch ein fehlschlagender Task
druckten den Hash oder das Passwort. `no_log: true` bleibt trotzdem Pflicht. Andere Module
geben aus, was man ihnen übergibt (L12 zeigt einen `copy`-Task, dessen `--diff`, und einen
`debug`-Task, die ein Token drucken), und Callback-Plugins (AWX/AAP-Jobausgabe) speichern
Task-Daten. Mit `no_log` zeigt Ansible `the output has been hidden`. Es versteckt auch
nützliche Fehlermeldungen - erst ergänzen, wenn der Task funktioniert.

#### Feature-Erkennung: Das Passwort-Mindestalter ist weg
shadow 4.20 hat das Passwort-Mindestalter ersatzlos entfernt - `chage -m/--mindays`,
`passwd -n`, `PASS_MIN_DAYS` in `login.defs` und das Feld `sp_min`. Upstream sieht darin eine
Schwachstelle (ein Benutzer kann ein geleaktes Passwort nicht sofort ersetzen) und lässt die
Werkzeuge absichtlich scheitern, damit Skripte auffallen, die sich darauf verlassen. Arch
liefert es als Erstes aus: `ansible.builtin.user` mit `password_expire_min` ruft `chage -m`
auf und scheitert dort.

Nicht "Arch hat kein Mindestalter" fest einbauen - jede Distribution zieht mit ihrem
nächsten shadow-Update nach. Das Werkzeug fragen und die Option per `omit` weglassen:
```yaml
- name: Does chage still support a minimum password age?
  ansible.builtin.command: chage --help
  register: cis_chage_help
  changed_when: false
  check_mode: false
  failed_when: false
- name: Create cisadmin with an aging policy
  vars:
    cis_chage_mindays: "{{ (cis_chage_help.stdout ~ cis_chage_help.stderr) is search('--mindays') }}"
  ansible.builtin.user:
    name: cisadmin
    password_expire_max: 365
    password_expire_min: "{{ 1 if cis_chage_mindays else omit }}"
```
Der Check akzeptiert ein leeres oder `0` als Mindestalter, wo `chage` es nicht mehr
unterstützt. Eine übrig gebliebene `PASS_MIN_DAYS`-Zeile in `login.defs` (3.02) ignoriert
shadow 4.20 - `useradd` funktioniert weiter.

### Unterschiede je Familie

| os_family | Hosts | Konto-Werkzeuge | Passwort-Mindestalter | Hinweise |
|---|---|---|---|---|
| Debian | debian, ubuntu | shadow `useradd`, `chage` | unterstützt | `visudo` in `/usr/sbin` |
| RedHat | rocky, alma, fedora | shadow `useradd`, `chage` | unterstützt | `visudo` in `/sbin` (rocky, alma) oder `/usr/sbin` (fedora) |
| Suse | opensuse | shadow `useradd`, `chage` | unterstützt | `visudo` in `/usr/sbin` |
| Archlinux | arch | shadow `useradd`, `chage` | mit shadow 4.20 entfernt | `visudo` in `/usr/bin` |
| Alpine | alpine | shadow `useradd`, `usermod`, `chage` im Lab-Image | unterstützt (`password_expire_max` gemessen) | ausgenommen: kein Python vor 0.02 |

Die Spalte `visudo` zeigt, was `command -v` ausgab (Messung aus L14). Die Lösung ruft
`/usr/sbin/visudo` auf und besteht auf jedem Host dieser Übung.

### Stolperfallen und gemessene Fakten

| Symptom | Ursache | Lösung |
|---|---|---|
| `changed` bei jedem Lauf, jedes Mal ein neuer Hash | `password_hash` ohne Salt zieht ein zufälliges | das Salt aus `inventory_hostname` ableiten |
| ein `changed` pro Host, nachdem sich der Control-Node geändert hat | libxcrypt und passlib machen aus demselben Salt verschiedene Strings | einmal zu erwarten; die Pakete des Control-Nodes gepinnt lassen |
| `user` scheitert auf arch an `chage -m` | shadow 4.20 hat kein Mindestalter | `chage --help` fragen, die Option per `omit` weglassen |
| der Check akzeptiert `$y$`, dein Hash ist `$6$...` | `password_hash` kennt nur md5, blowfish, sha256 und sha512 und erzeugt nie `$y$` | nichts zu tun; der Check ist weiter gefasst als der Filter |
| nach dem Rotieren des Vault-Passworts `changed=0` und der alte Hash bleibt | `update_password: on_create` setzt das Passwort nur beim Anlegen des Kontos | für ein Break-Glass-Konto den Standard `always` behalten |
| `Attempting to decrypt but no vault secrets found` | keine Passwortquelle für `vault.yml` | `--vault-password-file` angeben, auch bei `lab check` |
| der fehlschlagende Task zeigt nur `the output has been hidden` | `no_log: true` versteckt auch Fehler | beim Debuggen entfernen, danach wieder ergänzen |

### Praxis-Hinweise
- Passwort für sudo erforderlich (kein `NOPASSWD`), die Alterungsrichtlinie gilt, und jede
  Anmeldung des Kontos löst einen Alarm aus (auditd/SIEM). Das Passwort nach jeder Benutzung
  rotieren.
- Das Vault-Passwort getrennt vom Repository aufbewahren; in Produktion kommt es aus einem
  Skript, das einen Secret Store fragt (`--vault-password-file` darf ausführbar sein).
- Die Regel `no-log-password` von ansible-lint ist Opt-in und schlug bei der Lösung auch dann
  nicht an, wenn sie namentlich aktiviert war. Ein fehlendes `no_log` findet das Review, nicht
  der Linter.

### Weiterführend
- Lektion [L12 - Geheimnisse mit Ansible Vault](../../../docs/lessons/L12-secrets-with-ansible-vault.de.md): die Konzepte vor dieser Übung, mit Demos und Selbsttest-Fragen.
- Lektion [L08 - Konten und PAM](../../../docs/lessons/L08-accounts-and-pam.de.md): was die Alterungsfelder und das Hash-Präfix bedeuten.

## Musterlösung

Anzeigen mit `lab solution 4.04`, anwenden mit `lab solve 4.04`.
