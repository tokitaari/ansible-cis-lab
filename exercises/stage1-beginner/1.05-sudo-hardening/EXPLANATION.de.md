# 1.05 - sudo: PTY erzwingen und in Datei protokollieren: Erklärung

### Lösung
```yaml
- name: Harden sudo
  hosts: targets
  become: true
  tasks:
    - name: Deploy sudo defaults
      ansible.builtin.copy:
        dest: /etc/sudoers.d/50-cis
        content: |
          Defaults use_pty
          Defaults logfile="/var/log/sudo.log"
        owner: root
        group: root
        mode: "0440"
        validate: /usr/sbin/visudo -cf %s
```

### Warum Drop-in-Dateien
`/etc/sudoers` gehört dem Distributionspaket. `/etc/sudoers.d/` wird per `@includedir`
gelesen - deine Datei lässt sich sauber hinzufügen und entfernen. Dateien in diesem
Verzeichnis, die einen `.` enthalten oder auf `~` enden, werden **ignoriert** -
`50-cis.conf` würde stillschweigend nichts tun!

### validate rettet dich
Ohne Validierung legt ein einziger Tippfehler sudo auf allen Hosts in Sekunden lahm.
Die Wiederherstellung bräuchte Konsolenzugang (hier: `./lab.sh reset`). In Produktion
ist dieses Muster nicht verhandelbar.

### Hinweise
- sudo ab 1.9.14 aktiviert `use_pty` standardmäßig; explizit gesetzt dokumentiert es
  die Absicht und deckt ältere Versionen ab.
- `logfile` ergänzt syslog/journal, ersetzt es nicht.
- Ansibles eigene sudo-Aufrufe stehen jetzt in `/var/log/sudo.log` - schau rein.
- openSUSE Leap 16 verlegt Hersteller-Vorgaben nach `/usr/etc` (`/usr/etc/sudoers`, `/usr/etc/login.defs`);
  Dateien in `/etc` überschreiben sie. Das Paket liefert `/usr/etc/sudoers` mit Modus 0444, daher
  endet `visudo -c` schon auf einem unberührten Host mit 1. Die Datei gehört nicht dir - der Check
  toleriert genau diese Meldung und schlägt bei Syntaxfehlern oder falschen Rechten in `/etc` weiter fehl.

## Musterlösung

Anzeigen mit `lab solution 1.05`, anwenden mit `lab solve 1.05`.
