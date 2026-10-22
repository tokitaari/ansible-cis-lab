# 2.03 - Unnötige Kernelmodule deaktivieren: Erklärung

### Lösung
```yaml
- name: CIS - disable unneeded kernel modules
  hosts: targets
  become: true
  vars:
    cis_level: 1
    cis_disabled_modules_l1: [cramfs, freevxfs, hfs, hfsplus, jffs2, usb-storage]
    cis_disabled_modules_l2: [squashfs, udf, dccp, tipc, rds, sctp]
    cis_disabled_modules: >-
      {{ cis_disabled_modules_l1
         + (cis_disabled_modules_l2 if cis_level | int >= 2 else []) }}
  tasks:
    - name: Disable kernel module
      ansible.builtin.copy:
        dest: "/etc/modprobe.d/cis-{{ item }}.conf"
        content: |
          install {{ item }} /bin/false
          blacklist {{ item }}
        owner: root
        group: root
        mode: "0644"
      loop: "{{ cis_disabled_modules }}"
```

### Eine Datei pro Modul
Eine Datei pro Modul macht Ausnahmen trivial (eine Datei löschen) und Diffs lesbar.
Eine große Datei geht auch - wähle eine Konvention und bleib dabei.

### `install /bin/false` vs. `blacklist`
- `blacklist` stoppt nur das *automatische* Laden über Aliase (z. B. udev). Ein
  explizites `modprobe cramfs` funktioniert weiterhin.
- `install cramfs /bin/false` ersetzt den Ladebefehl - auch explizites Laden scheitert.
CIS verlangt beides.

### Level 2 (Bonus)
`squashfs` ist L2, weil Snaps (Ubuntu) und viele Live-/Installer-Images es brauchen.
`sctp`/`dccp`/`tipc`/`rds` hatten echte CVEs, die unprivilegierte Benutzer auslösen
konnten - manche Telekom-Stacks brauchen aber SCTP. Deshalb gibt es die Profiltrennung.

### Was der Container nicht zeigen kann
`modprobe -n -v cramfs` sollte `install /bin/false` ausgeben. Das beweist die
Konfiguration. Ob das Modul *gerade geladen* ist (`lsmod`), spiegelt deinen Host-Kernel,
nicht den Container - siehe `docs/CONTAINER_LIMITS.md`.

## Musterlösung

Anzeigen mit `lab solution 2.03`, anwenden mit `lab solve 2.03`.
