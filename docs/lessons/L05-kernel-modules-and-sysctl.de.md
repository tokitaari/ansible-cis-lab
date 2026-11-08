# L05 - Kernel-Härtung: Module und sysctl

*[English](L05-kernel-modules-and-sysctl.md)*

| Übungen | CIS-Abschnitte | Lesezeit | Baut auf |
|---|---|---|---|
| 2.03, 2.04 | 1.1.1, 1.5, 3.2, 3.3 | ~25 Min. | L00, L02, L04 |

Bisher haben wir Dateien, Pakete und Dienste geändert - Dinge, die einem Host gehören. Der Kernel
ist anders: Er entscheidet, welcher Code geladen werden darf und wie sich der Netzwerk-Stack
verhält, und im Lab teilen sich alle acht Targets **einen** Kernel. Diese Lektion behandelt die
beiden Einstellungen, die ihn erreichen (Kernelmodule und `sysctl`-Parameter), was ein
Ansible-Task mit beiden sicher tun kann und wo ein Container aus einem harmlos wirkenden
Schreibzugriff eine Änderung an deinem Host macht.

## Lernziele

Nach dieser Lektion kannst du ...

- [ ] einen Parameter pro Namespace von einem globalen unterscheiden und sagen, was das Schreiben eines globalen aus einem privilegierten Container bewirkt
- [ ] vorhersagen, welcher Wert gewinnt, wenn mehrere `sysctl.d`-Dateien denselben Schlüssel setzen
- [ ] mit `ansible.posix.sysctl` zwischen Persistieren, sofort Anwenden und Neuladen wählen und sagen, was jedes davon berührt
- [ ] eine `modprobe.d`-Regel schreiben, die das Laden blockiert, und sie zurücklesen, ohne etwas zu laden
- [ ] benennen, was eine solche Regel nicht abdeckt: `blacklist` allein, bereits geladene Module, `insmod`, das initramfs
- [ ] prüfen, ob die Collection eines Moduls installiert ist, und sie für ein eigenes Projekt deklarieren

## Theorie

### Ein Kernel, viele Sichten: namespaced und globale Parameter

Ein Container hat ein eigenes Dateisystem, eine eigene Prozessliste und einen eigenen
Netzwerk-Stack, aber keinen eigenen Kernel. Die Parameter des Kernels erscheinen als Dateien
unter `/proc/sys`, und jeder Schlüssel gehört zu einer von zwei Arten. **Namespaced** Schlüssel
haben eine Kopie pro Namespace: Die meisten `net.*`-Schlüssel gehören zum Netzwerk-Namespace,
jeder Container ändert also nur seinen eigenen Wert. **Globale** Schlüssel haben eine Kopie für
die ganze Maschine: `kernel.*`, `fs.*`, `vm.*`. Auch einige `net.*`-Schlüssel sind global;
schlage einen Schlüssel deshalb in der
[Kernel-Dokumentation](https://docs.kernel.org/admin-guide/sysctl/index.html) nach, wenn es
darauf ankommt.

Standardmäßig bekommt ein Container `/proc/sys` nur lesbar, die Frage stellt sich also nie. Die
Lab-Targets laufen **privilegiert**, weil sie ein echtes Init-System brauchen: Dort ist
`/proc/sys` beschreibbar, und ein Schreibzugriff auf einen globalen Schlüssel ändert den Host und
jeden anderen Container darauf. Dieses Play zeigt den namespaced Fall ohne Risiko: Es startet mit
`unshare` einen Wegwerf-Netzwerk-Namespace, ändert darin einen Wert und liest danach den
ursprünglichen noch einmal:

```yaml
- name: One value, two network namespaces
  hosts: targets:!alpine
  become: true
  gather_facts: false
  tasks:
    - name: Value in this network namespace
      ansible.builtin.command: sysctl -n net.ipv4.ip_default_ttl
      register: here
      changed_when: false
      check_mode: false
    - name: Set another value in a throw-away namespace and read it there
      ansible.builtin.command:
        argv:
          - unshare
          - --net
          - sh
          - -c
          - sysctl -w net.ipv4.ip_default_ttl=33 >/dev/null; sysctl -n net.ipv4.ip_default_ttl
      register: inside
      changed_when: false
      check_mode: false
    - name: Read the value in this namespace again
      ansible.builtin.command: sysctl -n net.ipv4.ip_default_ttl
      register: after
      changed_when: false
      check_mode: false
    - name: Compare the three readings
      ansible.builtin.debug:
        msg: "before {{ here.stdout }}, in the new namespace {{ inside.stdout }}, after {{ after.stdout }}"
```

Die Ausgabe ist `before 64, in the new namespace 33, after 64`: Die 33 gab es nur innen.
Probiere das nicht mit einem `kernel.*`-Schlüssel - es gibt keine zweite Kopie, und du würdest
die echte ändern. Lesen ist immer sicher (`sysctl -n <Schlüssel>`); frage vor dem Schreiben, wem
der Wert gehört.

Das Lab hat dafür einen Schalter: `lab_in_container: true` in
`ansible/inventory/group_vars/all.yml`. Tasks, die globalen Zustand berühren, beschränken sich
auf das Schreiben der Konfiguration, solange er gesetzt ist, und erledigen auf einer VM mit
`false` die volle Arbeit (siehe [Container-Grenzen](../CONTAINER_LIMITS.de.md)).

### sysctl: laufender Wert, Datei und die Reihenfolge der Dateien

Ein Parameter hat einen *laufenden* und meist auch einen *konfigurierten* Wert. `sysctl -w
Schlüssel=Wert` ändert den laufenden Kernel sofort und ist beim nächsten Boot vergessen (im Lab:
beim nächsten Start des Containers). Eine Datei in einem `sysctl.d`-Verzeichnis wird beim Boot
angewendet - auf den systemd-Familien durch `systemd-sysctl` - und ändert bis dahin nichts.
Härtung braucht beides, und ein Audit findet die Stellen, an denen sie auseinanderlaufen.

Setzen mehrere Dateien denselben Schlüssel, **gewinnt die zuletzt gelesene**. Die Verzeichnisse
(`/etc/sysctl.d`, `/run/sysctl.d`, `/usr/lib/sysctl.d` und einige weitere) werden zusammengeführt
und in der Reihenfolge der *Dateinamen* gelesen, egal in welchem Verzeichnis sie liegen; mit
`procps` kommt `/etc/sysctl.conf` ganz zuletzt. Eine Vendor-Datei `50-pid-max.conf` in
`/usr/lib/sysctl.d` wird daher nach einer `10-*.conf` aus `/etc` und vor deiner
`60-hardening.conf` gelesen, und eine verirrte `99-*.conf` überschreibt dich. Eine Datei in
`/etc` mit demselben Namen wie eine in `/usr/lib` ersetzt diese. Sieh dir das zusammengeführte
Ergebnis an, statt zu raten - auf einem systemd-Host ist das nur lesend:

```bash
ansible debian -b -m ansible.builtin.command -a "systemd-analyze cat-config sysctl.d"
```

`ansible.posix.sysctl` verwaltet einen Schlüssel pro Task. Seine Optionen entsprechen direkt den
beiden Zuständen:

| Option | Was sie steuert |
|---|---|
| `name`, `value` | der Schlüssel und der gewünschte Wert |
| `sysctl_file` | die Datei, in die die Zeile geschrieben wird (Standard `/etc/sysctl.conf`) |
| `sysctl_set` | `true`: den laufenden Wert zusätzlich jetzt schreiben (`sysctl -w`) |
| `reload` | Standard `true`: nach einer Änderung `sysctl -p <Datei>` ausführen - das wendet **jede Zeile dieser Datei** an, nicht nur deinen Schlüssel |
| `ignoreerrors` | weitermachen, wenn der laufende Kernel den Schlüssel nicht kennt |
| `state` | `present` (Standard) oder `absent`, um die Zeile zu entfernen |

Drei Verhaltensweisen sind wichtig. Das Modul vergleicht den *laufenden* Wert mit dem
gewünschten, bevor es handelt, ein zweiter Lauf meldet also `ok`. Im `--check`-Modus meldet es
`changed`, ohne zu schreiben. Und die beiden Modi scheitern bei einem Schlüssel, den es nicht
gibt, unterschiedlich - etwa `kernel.yama.ptrace_scope` auf einem Kernel ohne das
Sicherheitsmodul Yama: Mit `sysctl_set: true` schlägt der Task mit `cannot stat /proc/sys/...`
fehl und schreibt nichts; mit `sysctl_set: false` wird die Zeile ungeprüft geschrieben, ein
Tippfehler eingeschlossen, und du erfährst es erst, wenn die Datei angewendet wird.

```yaml
- name: Persist a per-namespace parameter and apply it now
  hosts: targets
  become: true
  gather_facts: false
  tasks:
    - name: Make sure the drop-in directory exists (rocky and alma ship without it)
      ansible.builtin.file:
        path: /etc/sysctl.d
        state: directory
        owner: root
        group: root
        mode: "0755"
    - name: Persist and apply the default TTL (the default value, so nothing changes in behaviour)
      ansible.posix.sysctl:
        name: net.ipv4.ip_default_ttl
        value: "64"
        sysctl_file: /etc/sysctl.d/70-lesson.conf
        sysctl_set: true
        reload: false
    - name: Read the file back
      ansible.builtin.command: cat /etc/sysctl.d/70-lesson.conf
      register: persisted
      changed_when: false
      check_mode: false
    - name: Show it
      ansible.builtin.debug:
        var: persisted.stdout_lines
```

`reload: false` hält den Task bei einem Schlüssel: Die Datei kann weitere Zeilen enthalten, und
`sysctl -p` würde sie alle anwenden - was spätestens dann zählt, wenn eine davon global ist.

### Kernelmodule: wer sie lädt und was `modprobe.d` stoppen kann

Ein Modul ist Kernel-Code, der bei Bedarf geladen wird: wenn du `modprobe` aufrufst, wenn der
Kernel Unterstützung braucht, die er nicht hat (ein Dateisystemtyp wird eingehängt, ein Socket
eines seltenen Protokolls geöffnet), und wenn ein Gerät erscheint. Jeder Weg endet in
`modprobe`, das zuerst `/etc/modprobe.d/*.conf` (und die Vendor-Verzeichnisse) liest. Zwei
Schlüsselwörter zählen hier:

- `install <Modul> <Befehl>` ersetzt das Laden durch den Befehl - mit `/bin/false` schlägt das
  Laden fehl. Es gilt für jedes `modprobe` dieses Namens, ob ausdrücklich oder nicht.
- `blacklist <Modul>` weist `modprobe` an, die eigenen Aliase des Moduls zu ignorieren (die
  Geräte- und Dateisystemnamen, die es über sich selbst meldet). Es wird nur angewendet, wenn der
  Aufrufer es verlangt (`modprobe -b`): Ein einfaches `modprobe <Modul>` mit dem echten Namen
  lädt es **trotzdem**.

Du siehst das, ohne etwas zu laden: `modprobe -n -v` macht einen Probelauf, `modprobe -c` gibt
die zusammengeführte Konfiguration in der Reihenfolge aus, in der kmod sie liest (von mehreren
`install`-Zeilen für einen Namen gilt die erste). Bei einem vorhandenen, nicht geladenen Modul
lauten die drei Fälle:

| Konfiguration | `modprobe -n -v <Modul>` gibt aus |
|---|---|
| keine | `insmod <Pfad>/<Modul>.ko` - es würde geladen |
| nur `blacklist` | dieselbe `insmod ...`-Zeile - wird trotzdem geladen; mit `-b` kommt keine Ausgabe |
| `install <Modul> /bin/false` | `install /bin/false` - der Befehl ersetzt das Laden |

Ein echtes `modprobe` eines Moduls mit `install /bin/false` endet mit `Error running install
command '/bin/false' ... retcode 1`: Das ist die Regel bei der Arbeit, kein Fehler deines Plays.
Eine Regel, die hält, hat die `install`-Zeile; `blacklist` schützt zusätzlich vor Aufrufern, die
sie beachten.

Was eine Regel **nicht** tut, ist genauso wichtig. Sie entlädt kein Modul, das schon geladen
ist, und wirkt nicht auf eines, das fest im Kernel einkompiliert ist. `insmod` lädt eine Datei,
die du nennst, und liest `modprobe.d` nicht. Beim Boot nötige Module kommen aus dem *initramfs*,
das eine eigene Kopie der Konfiguration vom Zeitpunkt seines Baus enthält (unter Debian kopiert
`mkinitramfs` `/etc/modprobe.d/*.conf`); auf einem echten Host braucht eine geänderte Regel also
einen initramfs-Neubau, bevor sie früh beim Boot greift. Laden und Entladen ist die Aufgabe von
`community.general.modprobe`, und das darf in einem Lab-Container nie laufen: `lsmod` in einem
Target zeigt die Module des Hosts, und `modprobe -r` würde sie vom Host entfernen.

Eine Regeldatei ist eine Datei, `copy` schreibt sie also (mit `loop` für mehrere, L04). Um den
Mechanismus zu sehen, ohne ein echtes Modul anzufassen, nimm einen Namen, den es nicht gibt. Auf
den kmod-Hosts (BusyBox auf alpine hat weder `-n` noch `-c`):

```yaml
- name: Write a module rule and read it back without touching a real module
  hosts: targets:!alpine
  become: true
  gather_facts: false
  tasks:
    - name: Rule for a module name that does not exist
      ansible.builtin.copy:
        dest: /etc/modprobe.d/lesson-demo.conf
        content: |
          install lesson_demo /bin/true
          blacklist lesson_demo
        owner: root
        group: root
        mode: "0644"
    - name: Dry run - what would modprobe do?
      ansible.builtin.command: modprobe -n -v lesson_demo
      register: dry
      changed_when: false
      check_mode: false
    - name: Dump the effective configuration
      ansible.builtin.command: modprobe -c
      register: dump
      changed_when: false
      check_mode: false
    - name: Show both
      ansible.builtin.debug:
        msg:
          - "dry run: {{ dry.stdout | trim }}"
          - "config: {{ dump.stdout_lines | select('search', 'lesson_demo') | list }}"
```

Der Probelauf gibt `install /bin/true` aus. Ohne die Datei würde er sagen, das Modul sei nicht
gefunden worden - die Targets haben kein Modulverzeichnis, das siehst du also auch bei einem
echten Modulnamen, *bevor* er konfiguriert ist. Die beiden Demo-Dateien sind harmlos;
`./lab.sh reset <host>` (`.\lab.ps1 reset <host>` unter Windows) oder ein `file`-Task mit
`state: absent` entfernt sie.

### Collections: woher `ansible.posix.sysctl` kommt

`ansible-core` bringt nur die `ansible.builtin`-Module mit. Alles andere liegt in *Collections*
mit dem Namen `namespace.name`, und ein Modul wird mit seinem voll qualifizierten Namen (FQCN)
angesprochen: `ansible.posix.sysctl`. Das Paket `ansible` auf dem Control-Node des Labs bündelt
die gängigen Collections (darunter `ansible.posix` und `community.general`), es muss also nichts
geholt werden. Frag nach, was installiert ist:

```bash
ansible-galaxy collection list ansible.posix
ansible-doc ansible.posix.sysctl | head -20
```

Eigene Projekte sollten sich nicht darauf verlassen, was zufällig installiert ist. Deklariere
die Collections in `collections/requirements.yml` und installiere sie mit `ansible-galaxy
collection install -r collections/requirements.yml`, damit ein Kollege oder ein CI-Job dieselben
Module bekommt:

```yaml
---
collections:
  - name: ansible.posix
    version: ">=2.0.0"
```

Ein Modul, das nicht gefunden wird, schlägt sofort mit `couldn't resolve module/action
'ansible.posix.sysctl'` fehl - das Zeichen, dass die Collection fehlt und nicht der Task falsch
ist.

## CIS-Hintergrund

Die vier Gruppen [im Kontrollkatalog](../../cis/controls.yml) sind im Lab "nur Konfiguration",
außer 3.3, aus den oben genannten Gründen. **1.1.1** (Level 1) verhindert, dass selten genutzte
Dateisystemtreiber geladen werden: Jeder Treiber ist Kernel-Code, der Daten verarbeitet, die ein
Angreifer beeinflussen kann - ein präpariertes Image auf einem Wechseldatenträger genügt -, und
ein Server braucht das Format fast nie. **3.2** (Level 2) tut dasselbe für seltene
Netzwerkprotokolle; es ist Level 2, weil das Abschalten echte Produkte bricht (Telekom-Software,
die SCTP spricht).

**3.3** (Level 1, die einzige Gruppe, die im Lab voll testbar ist) hindert einen Host daran, sich
wie ein Router zu verhalten, und schützt ihn vor gefälschtem oder umgeleitetem Verkehr; **1.5**
(Level 1) ist Prozess-Härtung - Adressraum-Randomisierung, keine Core-Dumps privilegierter
Programme, eingeschränktes Debugging zwischen Prozessen. Es sind Einzeiler, die fast nichts
kosten; was sie kosten, ist das Wissen, welcher Host das Gegenteil legitim braucht (ein Router,
ein Debugger auf einem Build-Server). Solche Ausnahmen gehören in Daten, nicht in einen
gepatchten Task (L04, L11).

## Plattformunterschiede

| os_family | Hosts | Werkzeuge im Lab-Image | `sysctl.d` beim Boot angewendet durch |
|---|---|---|---|
| Debian | debian, ubuntu | `kmod`, `procps` | `systemd-sysctl` |
| RedHat | rocky, alma, fedora | `kmod`, `procps-ng` | `systemd-sysctl` |
| Suse | opensuse | `kmod`, `procps` | `systemd-sysctl` |
| Alpine | alpine | BusyBox-Applets (`modprobe`, `sysctl`); das Paket `kmod` ist installiert, aber `/sbin/modprobe` ist BusyBox | OpenRC-Dienst `sysctl` - vorhanden, aber das Lab-Image aktiviert ihn nicht |
| Archlinux | arch | `kmod`, `procps-ng` | `systemd-sysctl` |

Die systemd-Familien teilen den Mechanismus; unterschiedlich ist, *wo die eigenen Dateien des
Herstellers liegen*. Unter Ubuntu 24.04 legt das Paket `procps` Dateien wie
`10-kernel-hardening.conf` direkt in `/etc/sysctl.d` ab; anderswo liegen sie in
`/usr/lib/sysctl.d`. Liste die Verzeichnisse (oder nimm `systemd-analyze cat-config`), bevor du
eine Dateinummer wählst.

Das `modprobe` auf alpine ist BusyBox 1.37: Es hat weder `-n` noch `-c` (im Lab geprüft), der
Probelauf oben funktioniert dort also nicht. Sein Konfigurationsparser kennt nur `alias`,
`options`, `include` und `blacklist` (BusyBox-Quelltext; ein Test mit BusyBox 1.36.1 bestätigt
es): Eine `install`-Zeile wird ignoriert, und `blacklist` greift für einen einfachen Namen nur mit
`-b`. Eine für kmod geschriebene Regeldatei wird dort korrekt *abgelegt*, aber BusyBox *setzt*
ihre `install`-Zeile nicht *durch*.
openSUSE liefert für viele selten genutzte Dateisysteme eigene `install`-Zeilen mit
(`/usr/lib/modprobe.d/60-blacklist_fs-<fs>.conf`), und die laden das Modul, wenn der Kernel danach
fragt. kmod liest die zusammengeführten Verzeichnisse in der Byte-Reihenfolge der Dateinamen und
nimmt die erste `install`-Zeile für ein Modul, deine Regel in einer später sortierten Datei gilt
dort also nicht, ein Name wie `00-...` sortiert dagegen zuerst (gemessen auf opensuse).
`modprobe --show-depends <modul>` zeigt die geltende Zeile - auch für ein Modul, das der Kernel
schon geladen hat und für das `modprobe -n -v` nichts ausgibt (gemessen auf den sieben
kmod-Targets). Minimale Images enthalten nicht immer `/etc/sysctl.d`:
rocky und alma liefern es nicht mit, lege das Verzeichnis zuerst an, sonst scheitert das
Schreiben mit `No such file or directory` (das Beispiel oben tut das). `/etc/modprobe.d` gibt
es auf allen acht Targets.

### In den Lab-Containern

- Alle acht Targets teilen den Host-Kernel, laufen privilegiert und haben keine Kopie seines
  Modulverzeichnisses. `lsmod` zeigt die Module des Hosts; `modprobe -r` und `rmmod` würden sie
  vom Host entladen - führe sie nie in einem Target aus.
- `systemd-modules-load` ist in den systemd-Targets maskiert, `systemd-sysctl` aber **nicht**
  und wendet `/etc/sysctl.d` bei jedem Start eines Targets an. Ein globaler Schlüssel, den du
  dort *persistierst*, erreicht den Host daher beim nächsten Start dieses Containers.
- Alpine wendet `sysctl.d` im Lab-Image beim Start nicht an, für einen namespaced Schlüssel
  zählt dort also der laufende Wert.
- Die Beispiele brauchen Python auf dem Target, alpine braucht daher zuerst 0.02 - die beiden
  Beispiele mit `targets:!alpine` überspringen es.

## Stolperfallen

| Symptom | Ursache | Lösung |
|---|---|---|
| Ein Modul mit nur einer `blacklist`-Zeile wird trotzdem geladen | `blacklist` wirkt nur mit `modprobe -b`; ein einfaches `modprobe <Name>` ignoriert es | `install <Modul> /bin/false` ergänzen; mit `modprobe -n -v` prüfen |
| `Error running install command '/bin/false'` | die Regel funktioniert; du hast ein echtes `modprobe` ausgeführt | mit `modprobe -n -v` oder `-c` prüfen, nicht zum Testen laden |
| `modprobe -n -v <Modul>` meldet, das Modul sei nicht gefunden | kein Modulverzeichnis im Container und noch keine Regel | erwartet; sobald die Regel existiert, lautet die Ausgabe `install ...` |
| `modprobe -n -v <Modul>` gibt nichts aus und endet mit 0 | der (Host-)Kernel hat das Modul schon geladen, der Probelauf bricht also ab, bevor er `install` liest | `modprobe --show-depends <Modul>` zeigt die Regel trotzdem |
| `lsmod` listet das Modul trotz Regel | es war vorher geladen, ist fest eingebaut oder kam aus dem initramfs | eine Regel stoppt *neue* Ladevorgänge; auf einem echten Host entladen, initramfs neu bauen |
| Andere Schlüssel der Datei haben sich auch geändert | `reload` ist standardmäßig `true` und führt `sysctl -p <Datei>` für die ganze Datei aus | `reload: false`, oder jede Zeile der Datei kennen |
| `cannot stat /proc/sys/kernel/yama/ptrace_scope` | `sysctl_set: true` bei einem Schlüssel, den der laufende Kernel nicht hat (hier: kein Yama) | nur die Datei schreiben oder `ignoreerrors: true`; pro Schlüssel entscheiden |
| Ein falsch geschriebener Schlüssel wird ohne Beschwerde geschrieben | mit `sysctl_set: false` fragt nichts den Kernel | den Schlüssel mit `sysctl -n` zurücklesen, sobald die Datei angewendet ist |
| Dein Wert ist nach einem Reboot weg | eine später sortierte Datei (`99-...`) oder `/etc/sysctl.conf` setzt den Schlüssel erneut | `systemd-analyze cat-config sysctl.d`; umnummerieren oder die Überschreibung entfernen |
| `couldn't resolve module/action 'ansible.posix.sysctl'` | die Collection ist nicht installiert | `ansible-galaxy collection install -r collections/requirements.yml` |

## Übungen

| Übung | Wofür diese Lektion vorbereitet |
|---|---|
| [2.03](../../exercises/stage2-building-blocks/2.03-disable-kernel-modules/README.de.md) | was `install` und `blacklist` tun, eine Regel zurücklesen ohne zu laden, warum im Lab nichts geladen oder entladen wird, ein `copy` pro Element |
| [2.04](../../exercises/stage2-building-blocks/2.04-sysctl-network/README.de.md) | namespaced vs. globale Schlüssel, laufender Wert vs. Datei, die Optionen `sysctl_set` und `reload`, Dateireihenfolge, ein Modul aus einer Collection |

Starte eine Übung mit `lab start <id>`; `lab show <id>` zeigt ihre README.

## Selbstkontrolle

1. Warum darf ein Play `net.ipv4.ip_default_ttl` in einem Lab-Target setzen, muss
   `kernel.*`-Schlüssel aber anders behandeln?

   <details><summary>Antwort</summary>

   `net.*`-Schlüssel gelten meist pro Netzwerk-Namespace: Das Target hat eine eigene Kopie, und
   der Schreibzugriff bleibt darin. `kernel.*`-Schlüssel sind global, und die Targets laufen
   privilegiert, ein Schreibzugriff ändert also die einzige Kopie, die der Host und alle anderen
   Container teilen.

   </details>

2. `/usr/lib/sysctl.d/50-a.conf` setzt einen Schlüssel auf 1, `/etc/sysctl.d/60-b.conf` auf 2
   und `/etc/sysctl.d/10-c.conf` auf 3. Welcher Wert ist nach dem Boot aktiv?

   <details><summary>Antwort</summary>

   2: Die Dateien werden in der Reihenfolge ihrer Namen gelesen (`10-c`, `50-a`, `60-b`),
   unabhängig vom Verzeichnis, und die letzte Zuweisung gewinnt. Eine `99-d.conf`, die den
   Schlüssel erneut setzt, würde ihn überschreiben.

   </details>

3. Ein Task hat `sysctl_set: false` und kein `reload`. Die Datei enthält drei Schlüssel. Was
   tut der Task außer eine Zeile zu schreiben?

   <details><summary>Antwort</summary>

   `reload` ist standardmäßig `true`, das Modul führt nach einer Änderung also `sysctl -p
   <Datei>` aus und wendet **alle drei Schlüssel** an - auch einen globalen, der in einem
   privilegierten Container den Host erreicht. `reload: false` schreibt nur.

   </details>

4. `blacklist foo` ist gesetzt, trotzdem lädt `modprobe foo` das Modul. Warum, und was stoppt es?

   <details><summary>Antwort</summary>

   `blacklist` betrifft die *Aliase* des Moduls und gilt nur, wenn der Aufrufer `-b` übergibt;
   der echte Name ist nicht betroffen. `install foo /bin/false` ersetzt das Laden für jedes
   `modprobe` dieses Namens.

   </details>

5. `modprobe -n -v foo` gibt nichts aus und endet mit 0, und `lsmod` listet `foo`. Ist die
   Regel kaputt?

   <details><summary>Antwort</summary>

   Nicht nach dieser Ausgabe. Bei einem Modul, das der Kernel schon geladen hat, bricht der
   Probelauf ab, bevor er `install` liest; `modprobe --show-depends foo` zeigt die Regel, auf die
   künftige Ladevorgänge treffen. Ein geladenes Modul bleibt geladen, bis es entladen wird, und es
   kann aus dem initramfs stammen, dessen Kopie der Konfiguration sich nur mit einem Neubau
   ändert. Auf einem echten Host entlädst du es (`community.general.modprobe`, `state: absent`);
   im Lab tust du das nie.

   </details>

6. Ein Task scheitert mit `cannot stat /proc/sys/kernel/yama/ptrace_scope`. Nenne zwei Wege,
   damit umzugehen, und was jeder aufgibt.

   <details><summary>Antwort</summary>

   Nur die Datei schreiben (`sysctl_set: false`): richtig für Hosts, die den Schlüssel haben,
   aber nichts prüft ihn jetzt. Oder `ignoreerrors: true`: Der Task läuft weiter, aber auch ein
   *Tippfehler* im Schlüssel wird verschluckt. Keines von beiden lässt den Parameter entstehen -
   das hängt vom Kernel ab.

   </details>

## Weiterführendes

- [`ansible.posix.sysctl`](https://docs.ansible.com/projects/ansible/latest/collections/ansible/posix/sysctl_module.html) und [`community.general.modprobe`](https://docs.ansible.com/projects/ansible/latest/collections/community/general/modprobe_module.html) - alle Optionen
- [Ansible-Collections verwenden](https://docs.ansible.com/projects/ansible/latest/collections_guide/index.html) - installieren, `requirements.yml`, FQCN
- [`sysctl.d(5)`](https://www.freedesktop.org/software/systemd/man/latest/sysctl.d.html) - die Verzeichnisse und die Reihenfolge, in der Dateien gelesen werden
- [Dokumentation zu `/proc/sys`](https://docs.kernel.org/admin-guide/sysctl/index.html) - was jeder Parameter bewirkt
- [`modprobe.d(5)`](https://man.archlinux.org/man/modprobe.d.5) - `install`, `blacklist` und die anderen Schlüsselwörter
- [Glossar](../GLOSSARY.de.md) - Begriffe dieser Lektion: `blacklist` (modprobe), collection,
  FQCN, `modprobe.d`, namespaced parameter, sysctl
