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

### Feature-Erkennung: Das Passwort-Mindestalter ist weg
shadow 4.20 hat das Passwort-Mindestalter ersatzlos entfernt - `chage -m/--mindays`,
`passwd -n`, `PASS_MIN_DAYS` in `login.defs` und das Feld `sp_min`. Upstream sieht darin eine
Schwachstelle (ein Benutzer kann ein geleaktes Passwort nicht sofort ersetzen) und lässt die
Werkzeuge absichtlich scheitern, damit Skripte auffallen, die sich darauf verlassen. Arch
liefert es als Erstes aus: `ansible.builtin.user` mit `password_expire_min` ruft `chage -m`
auf und scheitert dort.

Nicht "Arch hat kein Mindestalter" fest einbauen - jede Distribution zieht mit ihrem
nächsten shadow-Update nach. Das Werkzeug fragen und die Option per `omit` weglassen:
```yaml
- name: Does chage still support a minimum password age?
  ansible.builtin.command: chage --help
  register: cis_chage_help
  changed_when: false
  check_mode: false
  failed_when: false
- name: Create cisadmin with an aging policy
  vars:
    cis_chage_mindays: "{{ (cis_chage_help.stdout ~ cis_chage_help.stderr) is search('--mindays') }}"
  ansible.builtin.user:
    name: cisadmin
    password_expire_max: 365
    password_expire_min: "{{ 1 if cis_chage_mindays else omit }}"
```
Der Check akzeptiert ein leeres oder `0` als Mindestalter, wo `chage` es nicht mehr
unterstützt. Eine übrig gebliebene `PASS_MIN_DAYS`-Zeile in `login.defs` (3.02) ignoriert
shadow 4.20 - `useradd` funktioniert weiter.

### Break-Glass-Hygiene
Passwort für sudo erforderlich (kein NOPASSWD), Alterungsrichtlinie gilt, Alarm bei jeder
Anmeldung dieses Kontos (auditd/SIEM), Vault-Passwort getrennt vom Repository aufbewahren.

## Musterlösung

Anzeigen mit `lab solution 4.04`, anwenden mit `lab solve 4.04`.
