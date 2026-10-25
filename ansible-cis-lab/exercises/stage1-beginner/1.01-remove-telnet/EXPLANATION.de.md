# 1.01 - Unsichere Client-Pakete entfernen: Erklärung

### Lösung
```yaml
- name: Remove insecure client packages
  hosts: targets
  become: true
  tasks:
    - name: Remove telnet client
      ansible.builtin.package:
        name: telnet
        state: absent
```

### Warum `package` und nicht `apt`/`dnf`
`package` liest den Fact `ansible_facts.pkg_mgr` und ruft das passende Modul auf.
Für einfaches Installieren/Entfernen ist das ideal. Sobald du managerspezifische
Optionen brauchst (`autoremove`, `update_cache`, Repos), wechselst du zum
spezifischen Modul.

### Namen unterscheiden sich je Distribution
Telnet heißt meist `telnet`, ist auf Arch aber Teil von `inetutils` (zusammen mit
`hostname`!) und auf Alpine Teil von `busybox-extras`. Auf Arch blind `inetutils` zu
entfernen, würde auch `hostname` entfernen. Deshalb führt Stufe 2 Variablen pro
Familie ein.

### Debian/Ubuntu: Übergangspakete
Auf aktuellen Debian/Ubuntu kann `telnet` ein leeres Übergangspaket sein, das
`inetutils-telnet` nachzieht. Entfernst du `telnet`, bleibt das Binary liegen. Prüfe
immer die *Wirkung* (Binary weg), nicht nur den Paketstatus - die CIS-Prüfprozedur
macht es genauso.

### Check-Modus
`--check --diff` zeigt, was sich ändern *würde*, ohne etwas zu ändern. Nutze es vor
jedem Härtungslauf in Produktion.

## Musterlösung

Anzeigen mit `lab solution 1.01`, anwenden mit `lab solve 1.01`.
