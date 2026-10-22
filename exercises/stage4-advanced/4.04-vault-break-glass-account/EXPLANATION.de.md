# 4.04 - Ansible Vault: Notfall-Admin-Konto: Erklärung

### Vault-Grundlagen
```bash
ansible-vault create  --vault-password-file .vault-pass vault.yml
ansible-vault view    --vault-password-file .vault-pass vault.yml
ansible-vault rekey   ...    # neues Vault-Passwort
ansible-playbook playbook.yml --vault-password-file .vault-pass
```
Konvention: Geheimnisse heißen `vault_*` und werden aus normalen Variablen referenziert
(`cisadmin_password: "{{ vault_cisadmin_password }}"`), damit `grep` findet, wo Geheimnisse
genutzt werden, ohne etwas zu entschlüsseln.

### Warum das Salt zählt
`password_hash('sha512')` erzeugt ein Zufallssalt → jeder Lauf ein anderer Hash → jedes
Mal `changed`, und jeder Lauf macht ein von einem Menschen gesetztes Passwort ungültig.
Ein deterministisches Salt aus dem Hostnamen liefert pro Lauf denselben Hash, aber
zwischen Hosts verschiedene Hashes (ein geknackter Hash verrät keine Wiederverwendung).

### no_log
Ohne zeigt `-v` den Hash, und Callback-Plugins (Logs, AWX/AAP-Jobausgabe) speichern ihn.
Mit zeigt Ansible `the output has been hidden`. Es versteckt auch nützliche
Fehlermeldungen - erst ergänzen, wenn der Task funktioniert.

### Break-Glass-Hygiene
Passwort für sudo erforderlich (kein NOPASSWD), Alterungsrichtlinie gilt, Alarm bei jeder
Anmeldung dieses Kontos (auditd/SIEM), Vault-Passwort getrennt vom Repository aufbewahren.

## Musterlösung

Anzeigen mit `lab solution 4.04`, anwenden mit `lab solve 4.04`.
