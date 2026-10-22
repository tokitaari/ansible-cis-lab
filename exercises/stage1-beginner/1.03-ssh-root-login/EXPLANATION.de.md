# 1.03 - SSH: Root-Login und leere Passwörter verbieten: Erklärung

### Lösung
```yaml
- name: Harden sshd authentication
  hosts: targets
  become: true
  tasks:
    - name: Deploy sshd hardening drop-in
      ansible.builtin.copy:
        dest: /etc/ssh/sshd_config.d/00-cis-hardening.conf
        content: |
          PermitRootLogin no
          PermitEmptyPasswords no
        owner: root
        group: root
        mode: "0600"
        validate: /usr/sbin/sshd -t -f %s
      notify: Reload sshd
  handlers:
    - name: Reload sshd
      ansible.builtin.service:
        name: "{{ 'ssh' if ansible_facts.os_family == 'Debian' else 'sshd' }}"
        state: reloaded
```

### Der erste Treffer gewinnt
sshd nimmt bei den meisten Schlüsselwörtern den **ersten** gelesenen Wert. Mit
`Include /etc/ssh/sshd_config.d/*.conf` ganz oben wird `00-cis-hardening.conf` vor
`10-lab-legacy.conf` gelesen, also gewinnen deine Werte. Nennst du sie `99-...`,
gewinnt die Legacy-Datei. Dort liegen auch Distributionsdateien (`50-redhat.conf` auf
EL, cloud-init-Dateien auf Ubuntu) - ein weiterer Grund für ein niedriges Präfix.

### validate
Ansible schreibt den neuen Inhalt in eine Temp-Datei, führt `sshd -t -f <tempdatei>`
aus und verschiebt sie nur bei Exit-Code 0 an ihren Platz. Achtung: das prüft das
Fragment *allein*. Ein Fragment, das nur im Zusammenspiel ungültig ist, rutscht durch -
Stufe 2 ergänzt eine Prüfung der Gesamtkonfiguration.

### Handler
Handler laufen einmal am Ende des Plays, und nur wenn sie benachrichtigt wurden. Fünf
Tasks, die sshd ändern → ein Reload. `reloaded` (SIGHUP) erhält bestehende Verbindungen -
auch die, die Ansible gerade nutzt; `restarted` ginge bei sshd auch, Reload ist aber
die schonendere Gewohnheit.

### Warum nicht `lineinfile` auf sshd_config?
Geht - aber Distributionen liefern unterschiedliche Hauptdateien, und Paket-Updates
können sie ersetzen. Ein Drop-in, das komplett dir gehört, ist leichter nachvollziehbar
und leichter zu entfernen.

### Praxis
Bevor du in Produktion sshd anfasst: zweite Sitzung offen halten, `validate` nutzen
und in Wellen ausrollen (`serial`, Stufe 5).

## Musterlösung

Anzeigen mit `lab solution 1.03`, anwenden mit `lab solve 1.03`.
