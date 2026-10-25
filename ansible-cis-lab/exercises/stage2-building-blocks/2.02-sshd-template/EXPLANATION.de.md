# 2.02 - SSH-Server-Härtung mit Jinja2-Template: Erklärung

### Lösung (Auszug)
```yaml
tasks:
  - name: Deploy sshd hardening drop-in
    ansible.builtin.template:
      src: sshd_cis.conf.j2
      dest: /etc/ssh/sshd_config.d/00-cis-hardening.conf
      owner: root
      group: root
      mode: "0600"
      validate: /usr/sbin/sshd -t -f %s
    notify: Reload sshd
  - name: Validate the complete sshd configuration
    ansible.builtin.command: /usr/sbin/sshd -t
    changed_when: false
handlers:
  - name: Reload sshd
    ansible.builtin.service:
      name: "{{ 'ssh' if ansible_facts.os_family == 'Debian' else 'sshd' }}"
      state: reloaded
```
Vollständige Dateien: `lab solution 2.02`.

### Zwei Validierungsebenen
1. `validate:` prüft das Fragment isoliert, *bevor* es die Datei ersetzt.
2. `sshd -t` prüft, was sshd tatsächlich laden würde (Hauptdatei + alle Drop-ins).
Scheitert (2), bricht das Play ab und der Handler läuft nie → der laufende Daemon
behält seine alte, funktionierende Konfiguration. Du korrigierst und startest neu.
Diese Reihenfolge ist der ganze Trick: Handler laufen am Ende des Plays.

### Aussperr-Analyse (Bonus)
- `AllowGroups ansible` - nur Mitglieder der Gruppe `ansible` dürfen sich anmelden. Der
  Lab-Benutzer ist Mitglied. In Produktion muss die Liste deine Admin-Gruppe *und*
  dein Automatisierungskonto enthalten - ein klassischer Ausfall.
- `PermitRootLogin no` - kein Problem, Ansible meldet sich als `ansible` an und nutzt sudo.
- `KexAlgorithms` - das OpenSSH des Control Nodes muss mindestens einen Algorithmus
  teilen. Sehr alte Clients (z. B. Legacy-Jump-Hosts) können scheitern.
- `ClientAliveInterval 15` mit `CountMax 3` - Ansibles `ControlPersist`-Verbindungen
  überleben, weil der Client auf Keepalives antwortet.

### crypto-policies (Bonus)
Auf EL/Fedora bindet `50-redhat.conf` die System-Crypto-Policy ein. Deine `00-`-Datei
wird zuerst gelesen, also gewinnen deine Algorithmenlisten. Alternative auf diesen
Systemen: ein eigenes Crypto-Policy-Modul (`update-crypto-policies --set DEFAULT:CIS`) -
sauberer, aber Red-Hat-spezifisch.

### Warum `ansible_managed`
Es sagt dem nächsten Admin: "Nicht von Hand ändern, deine Änderung wird überschrieben."

## Musterlösung

Anzeigen mit `lab solution 2.02`, anwenden mit `lab solve 2.02`.
