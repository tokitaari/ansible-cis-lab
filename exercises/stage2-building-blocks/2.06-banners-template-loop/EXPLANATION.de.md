# 2.06 - Alle Login-Banner aus einem Template: Erklärung

### Was der Check prüft
`lab check 2.06` führt `check.yml` auf allen acht Targets aus und dann dein Playbook noch einmal
mit `--check`; erwartet wird `changed=0` (`meta.yml` sagt `idempotency: true`). Für `/etc/motd`,
`/etc/issue` und `/etc/issue.net` liest er jeweils den Text und prüft:
- er enthält `lab_org_name` und das Wort *authorized* (oder *authorised*, Groß- und
  Kleinschreibung egal);
- er enthält keine der getty-Escapes `\m`, `\r`, `\s`, `\v` und nicht den Fact `distribution`
  des Hosts (Groß- und Kleinschreibung egal);
- die Datei ist `0644` und `root:root`.

Nicht geprüft wird: andere Escapes wie `\S` (der hübsche Name), `\l` (das Terminal) oder `\n`
(der Hostname) - ein Banner mit `\S` besteht, gemessen mit dem Ausdruck des Checks -, eine
Versionsnummer ohne den Namen der Distribution, und dass ein Template und ein Task mit Schleife
die drei Dateien erzeugt haben. Die frischen Targets scheitern mit Absicht: jede `/etc/issue` und
`/etc/issue.net` enthält den Namen der Distribution und `\r \m`.

### So funktioniert es

#### Ein Template, drei Ziele
```yaml
- name: Deploy login banners
  ansible.builtin.template:
    src: banner.j2
    dest: "{{ item }}"
    owner: root
    group: root
    mode: "0644"
  loop: [/etc/motd, /etc/issue, /etc/issue.net]
```
Das Template ist reiner Text mit `{{ lab_org_name }}`. Drei Dateien, eine Quelle: eine Änderung
am Rechtstext ist eine Bearbeitung, und `--diff` zeigt sie je Datei.

#### Woher die Variable kommt
`lab_org_name` steht in `/lab/ansible/inventory/group_vars/all.yml`. Gemessen für Lektion L07:
Inventory-`group_vars` verlieren gegen Play-`vars:`, `vars/main.yml` einer Rolle schlägt beide,
und `-e` schlägt alles. `ansible-inventory --host alpine` zeigt, was bei einem Host ankommt -
nutze es für den Bonus mit `host_vars`.

#### Hier kein `ansible_managed`
In Konfigurationsdateien hilft der Kommentar; in einem Banner läse ihn jeder Benutzer. Entscheide
bewusst.

#### Wer welche Datei zeigt
- `/etc/issue` gibt das getty der Konsole vor dem Login-Prompt aus. Es ersetzt Escapes wie `\r`
  (Kernel-Release) und `\m` (Architektur) - so sickern OS-Informationen durch.
- `/etc/issue.net` zeigt sshd nur, wenn `Banner` darauf zeigt. Auf allen Lab-Hosts meldet sshd zu
  Beginn `banner none`: die Datei wird für CIS gepflegt, aber niemand sieht sie, bis die
  sshd-Konfiguration aus 2.02 (`Banner /etc/issue.net`) aktiv ist.
- `/etc/motd` erscheint nach dem Login - über `pam_motd` oder über `PrintMotd` von sshd. Die
  Tabelle zeigt, was jeder Host nutzt; auf opensuse fand die Messung keins von beiden in
  `/etc/pam.d` (`PrintMotd no`).

#### Erzeugte Tagesmeldung (Bonus 2)
Manche Hosts ergänzen das, was der Benutzer sieht, um Text aus Skripten oder Verzeichnissen.
Ubuntu führt die Skripte in `/etc/update-motd.d` aus (`00-header` und drei weitere), Debian hat
eins namens `10-uname`; beide Hosts haben eine `/run/motd.dynamic`, die `pam_motd` anzeigt.
opensuse liefert `/usr/lib/motd.d/welcome`. CIS geht es darum, was der Benutzer *sieht*: nimm
solchen Skripten das Ausführungsbit oder entferne den dynamischen Teil aus der PAM-Konfiguration,
und dokumentiere es.

#### Symbolische Links auf fedora
Auf fedora sind `/etc/issue` und `/etc/issue.net` symbolische Links nach `/usr/lib` (`stat` zeigt
Modus `777` und eine Größe von 16 und 20 Byte). `template` ersetzt den Link durch eine normale
Datei und lässt die Datei des Herstellers unberührt (gemessen: Lauf 1 `changed`, Lauf 2 `ok`).
Das ist hier gewollt - ein Paket-Update kann dein Banner nicht mehr über den Link überschreiben.

### Hinweise je Familie
| `os_family` | Hosts | `/etc/motd` zu Beginn | Erzeugte Teile | Nach einem SSH-Login angezeigt durch |
|---|---|---|---|---|
| Debian | debian, ubuntu | debian: Lizenztext von Debian; ubuntu: keine | debian: `update-motd.d/10-uname`; ubuntu: vier Skripte in `update-motd.d` | `pam_motd` |
| RedHat | rocky, alma, fedora | leer | `/etc/motd.d` und `/usr/lib/motd.d` leer | `pam_motd` |
| Suse | opensuse | keine | `/usr/lib/motd.d/welcome` | kein `pam_motd` in `/etc/pam.d`, `PrintMotd no` |
| Archlinux | arch | keine | keine | `pam_motd` in `system-login` |
| Alpine | alpine | Willkommenstext (284 Byte) | keine | sshd `PrintMotd yes` |

`/etc/issue` und `/etc/issue.net` beginnen auf allen acht Hosts als "Welcome to <Distribution>
<Version> \r \m".

### Stolperfallen und gemessene Fakten
| Symptom | Ursache | Lösung |
|---|---|---|
| Der Check scheitert auf einem frischen Host | die mitgelieferten `issue`-Dateien nennen die Distribution und enthalten `\r \m` | dein Template ausrollen |
| Benutzer sehen nach dem Login weiter die OS-Version | erzeugte Tagesmeldung (Debian, Ubuntu) | die Skripte abschalten, dokumentieren |
| Der Check besteht mit `\S` im Banner | er sucht nur nach `\m \r \s \v` | gar keine Escapes in deinem Text |
| Beim Login erscheint "Ansible managed" | `ansible_managed` im Template | in Bannern weglassen |
| `/etc/issue.net` sieht nie jemand | sshd `Banner none` | `Banner /etc/issue.net` in sshd setzen (2.02) |

### Praxis-Hinweise
- Der Rechtstext gehört jemand anderem (Rechtsabteilung, Sicherheitsbüro). Halte ihn in einer
  Variablen oder einer Datei und lass Änderungen über das Repository prüfen.
- Für die Warnung an Unbefugte zählt das Banner vor der Anmeldung (`issue.net` über sshd); die
  Tagesmeldung kommt dafür zu spät.

### Weiterführend
- Lektion [L04 - Plattformunterschiede als Daten: Dictionaries, Schleifen, Jinja2 und Templates](../../../docs/lessons/L04-platform-differences-as-data.de.md): Templates, Schleifen und Variablen - die Konzepte vor dieser Übung.
- Übung [0.04 - Erstes Härtungs-Playbook: SSH-Warnbanner](../../stage0-foundations/0.04-first-playbook-banner/README.de.md): die Version mit einer Datei, die diese Übung verallgemeinert.
- Übung [2.02 - SSH-Server-Härtung mit Jinja2-Template](../2.02-sshd-template/README.de.md): wo das SSH-`Banner` hingehört.

## Musterlösung

Anzeigen mit `lab solution 2.06`, anwenden mit `lab solve 2.06`.
