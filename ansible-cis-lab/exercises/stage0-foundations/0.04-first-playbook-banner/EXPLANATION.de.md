# 0.04 - Erstes Härtungs-Playbook: SSH-Warnbanner: Erklärung

### Lösung
```yaml
- name: Set a neutral SSH warning banner
  hosts: targets
  become: true
  tasks:
    - name: Write /etc/issue.net
      ansible.builtin.copy:
        dest: /etc/issue.net
        content: |
          Authorized access only. Activity on this system is monitored and logged.
        owner: root
        group: root
        mode: "0644"
```

### Idempotenz - der Kern von Ansible
`copy` vergleicht Prüfsumme, Eigentümer, Gruppe und Modus mit dem Sollzustand und
handelt nur bei Abweichungen. Zweiter Lauf → `ok`, nicht `changed`. Jeder Task, den du
ab jetzt schreibst, muss sich so verhalten. `lab check` prüft das mit einem `--check`-Lauf.

### Stolperfalle: Modus ohne Anführungszeichen
`mode: 644` ist die YAML-Ganzzahl 644 = oktal 1204 → eine seltsame Sticky-Berechtigung.
`mode: 0644` funktioniert in YAML 1.1, ist aber fragil. Immer quoten: `mode: "0644"`.

### Hinweis: das Banner wird noch nicht angezeigt
sshd zeigt `/etc/issue.net` erst, wenn `Banner /etc/issue.net` konfiguriert ist.
Das ist Teil der sshd-Härtung in 2.02.

### Praxis
Bannertexte sind oft rechtliche Vorgaben (Betriebsrat, Rechtsabteilung). Halte sie
in einer Variable, damit sie zentral änderbar sind - das machst du in 2.06.

## Musterlösung

Anzeigen mit `lab solution 0.04`, anwenden mit `lab solve 0.04`.
