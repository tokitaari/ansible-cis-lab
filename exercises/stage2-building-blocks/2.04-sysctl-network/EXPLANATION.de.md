# 2.04 - Kernelparameter: Netzwerk-Härtung per sysctl: Erklärung

### Was der Check prüft
`lab check 2.04` führt `check.yml` auf allen acht Targets aus und dann dein Playbook noch einmal
mit `--check`; erwartet wird `changed=0` (`meta.yml` sagt `idempotency: true`). `check.yml`:
- liest die 16 Netzwerkparameter live mit einem einzigen `sysctl -n` und vergleicht jeden Wert
  als Text mit dem erwarteten;
- erwartet für jeden der 16 eine Zeile `key = value` (Leerzeichen um `=` erlaubt) in
  `/etc/sysctl.d/60-cis-network.conf`;
- erwartet eine solche Zeile für jeden der drei globalen Parameter in
  `/etc/sysctl.d/60-cis-kernel.conf`.

Nicht geprüft wird: der Live-Wert der drei globalen Parameter (mit Absicht - sie gehören dem
Host-Kernel, und der Check könnte deinen Wert nicht von dem des Hosts unterscheiden), ob du
`ansible.posix.sysctl`, zwei Dicts oder `dict2items` verwendest, und was sonst in den beiden
Dateien steht. Eine Live-Änderung an einem globalen Parameter bleibt unbemerkt: sie zu vermeiden
ist dein Teil des Vertrags.

### So funktioniert es

#### Namespace-gebundene und globale Parameter
`net.*`-Parameter gibt es einmal pro Netzwerk-Namespace, und jeder Container hat seinen eigenen.
Die `kernel.*`- und `fs.*`-Parameter dieser Übung sind global: es gibt einen Wert für die ganze
Maschine. Die Lab-Targets laufen privilegiert, also hält nichts einen Schreibzugriff auf einen
globalen Schlüssel aus einem Target heraus auf - er ändert den Kernel der Maschine, auf der
Docker läuft. Gemessen auf frischen Targets: die drei globalen Werte sind auf allen acht Hosts
gleich (`randomize_va_space=2`, `suid_dumpable=2`, `ptrace_scope=1`), weil es die des Hosts sind.
Die Netzwerkwerte starten auf jedem Host weit weg von den CIS-Werten: `ip_forward=1`,
`rp_filter=2` (loser Modus), `send_redirects=1`, `log_martians=0`; die Übung ändert also wirklich
Live-Werte.

#### Drei Schalter: `sysctl_file`, `sysctl_set`, `reload`
| Option | Wirkung |
|---|---|
| `sysctl_file` | die Datei, in die die Zeile geschrieben wird (Default `/etc/sysctl.conf`) |
| `sysctl_set: true` | den Wert zusätzlich jetzt nach `/proc/sys` schreiben (Default `false`) |
| `reload: true` (Default) | `sysctl -p <datei>` ausführen - das lädt **jede** Zeile der Datei |

Wie das Modul entscheidet (im Quelltext von `ansible.posix` 2.2.2 gelesen, in einem eigenen
Netzwerk-Namespace gemessen): es vergleicht die Zeile in der Datei mit dem gewünschten Wert. Mit
`sysctl_set: true` vergleicht es zusätzlich den Live-Wert. Mit `reload: true` und korrekter Datei
vergleicht es trotzdem den Live-Wert, und weicht der ab, führt es `sysctl -p` für die ganze Datei
aus. Der Default `reload: true` auf `60-cis-kernel.conf` würde also alle drei globalen Werte in den
Host-Kernel laden, beim ersten Lauf und bei jedem späteren, in dem der Host-Wert abweicht. Unter
`--check` schreibt das Modul nichts.

Die Musterlösung macht die Entscheidung zu einer Variablen:
```yaml
cis_apply_global_sysctl: "{{ not (lab_in_container | default(false)) }}"
```
und nutzt sie für `sysctl_set` und `reload` des globalen Tasks. `lab_in_container` ist im
Lab-Inventory `true` (`group_vars/all.yml`); auf einem echten Server setzt derselbe Code die Werte
sofort.

#### Werte sind Text
Das Modul deklariert `value` als String: `value: 0` kommt als `"0"` an, `true`/`false` werden zu
`1`/`0`. `| string` in der Lösung schadet nicht, ist aber unnötig. Werte mit mehreren Zahlen
(manche `net.ipv4`-Bereiche) werden Wort für Wort verglichen.

#### Die Datei wirkt erst, wenn sie jemand liest
`/etc/sysctl.d/*.conf` wird beim Booten gelesen - auf systemd-Hosts von
`systemd-sysctl.service`, unter OpenRC vom Dienst `sysctl`. In den Lab-Containern ist das je Host
verschieden (siehe Tabelle): die Unit ist auf fünf Hosts aktiv, fehlt auf rocky und alma, und
Alpines Dienst `sysctl` steht in keinem Runlevel - das Lab-Image aktiviert ihn nicht. Deshalb
werden die Netzwerkwerte zusätzlich live gesetzt. `./lab.sh reset` legt den Container neu an:
Dateien und Live-Werte sind wieder im Ausgangszustand.

#### Warum die Parameter wichtig sind
- `ip_forward=0`, `send_redirects=0` - ein Server ist kein Router.
- `accept_redirects=0`, `secure_redirects=0` - ICMP-Redirects können deinen Verkehr umleiten
  (MITM).
- `accept_source_route=0` - der Absender darf den Pfad nicht wählen.
- `rp_filter=1` - Pakete verwerfen, deren Absenderadresse nicht zurückgeroutet werden kann
  (strikter Modus; `2`, der Startwert hier, prüft nur, ob die Absenderadresse überhaupt
  erreichbar ist).
- `log_martians=1` - unmögliche Absenderadressen protokollieren.
- `tcp_syncookies=1` - SYN-Floods überstehen.
- `randomize_va_space=2` - volles ASLR; `suid_dumpable=0` - keine Core-Dumps mit Geheimnissen;
  `ptrace_scope=1` - Prozesse können sich nur an eigene Kindprozesse hängen.

#### Collections
`ansible.posix.sysctl` ist nicht in ansible-core. Das Lab-Image installiert das
Community-Paket `ansible`, das es mitbringt. In eigenen Projekten deklarierst du es in
`collections/requirements.yml`.

### Hinweise je Familie
| `os_family` | Hosts | `/etc/sysctl.d` zu Beginn | Beim Booten im Container gelesen |
|---|---|---|---|
| Debian | debian, ubuntu | vorhanden (`README.sysctl`) | `systemd-sysctl.service` aktiv |
| RedHat | rocky, alma, fedora | rocky, alma: **fehlt**; fedora: `99-sysctl.conf` | rocky, alma: keine solche Unit; fedora: aktiv |
| Suse | opensuse | vorhanden, leer | aktiv |
| Archlinux | arch | vorhanden, leer | aktiv |
| Alpine | alpine | vorhanden (`README`) | OpenRC-Dienst `sysctl` in keinem Runlevel |

Startwerte: auf allen acht Hosts gleich, außer `net.ipv4.conf.default.accept_redirects`, das auf
opensuse `0` ist und sonst `1` (`conf.all.accept_redirects` ist überall `0`).

### Stolperfallen und gemessene Fakten
| Symptom | Ursache | Lösung |
|---|---|---|
| rocky, alma: `[Errno 2] No such file or directory: '/etc/sysctl.d/.ansible_m_sysctl_....conf'` | das Verzeichnis fehlt, und das Modul legt es nicht an | vorher ein `file`-Task mit `state: directory` |
| Ein vertippter Schlüssel landet ohne Fehler in der Datei | mit `sysctl_set: false` fasst das Modul `/proc/sys` nie an | die Schlüsselliste kurz und geprüft halten; `sysctl_set: true` meldet bei Namespace-Schlüsseln `cannot stat /proc/sys/...` |
| `suid_dumpable` des Hosts hat sich geändert | `reload` auf dem Default gelassen oder `sysctl_set: true` bei einem globalen Schlüssel | beide `false` im Container (`lab_in_container`) |
| Nach `./lab.sh reset` sind die Werte weg | das Target wurde neu angelegt | das Playbook erneut ausführen |
| Ein `net.ipv6.*`-Schlüssel scheitert mit `cannot stat /proc/sys/...` (Bonus) | IPv6 ist in diesem Namespace aus, also gibt es den Schlüssel nicht | vorher auf `/proc/sys/net/ipv6` prüfen |

### Praxis-Hinweise
- Auf Container-Plattformen darf ein Pod oder Container nur Namespace-gebundene Parameter setzen;
  globale sind eine Eigenschaft des Knotens und gehören in dessen eigenes
  Konfigurationsmanagement.
- Setze jeden Parameter in genau einer Datei. Setzen zwei Dateien denselben Schlüssel, gewinnt
  beim Booten die später gelesene (`sysctl.d(5)`), und wer nur deine liest, sieht den falschen
  Wert.

### Weiterführend
- Lektion [L05 - Kernel-Härtung: Module und sysctl](../../../docs/lessons/L05-kernel-modules-and-sysctl.de.md): Namespaces, Persistenz und Booten, die Modul-Optionen - die Konzepte vor dieser Übung.
- Übung [2.03 - Unnötige Kernelmodule deaktivieren](../2.03-disable-kernel-modules/README.de.md): die andere Hälfte der Lektion, mit derselben Frage Host gegen Container.

## Musterlösung

Anzeigen mit `lab solution 2.04`, anwenden mit `lab solve 2.04`.
