# 4.02 - Profile (Level 1/2) und dokumentierte Ausnahmen

## Hinweis 1

Zuerst die Vorabprüfung: ein `assert`-Task mit Schleife über `cis_exceptions` und `that:`-Prüfungen für `item.id | default('') in known_ids`, `item.reason | default('') | string | trim | length > 0`, `item.expires is defined` und `(item.expires | string | to_datetime('%Y-%m-%d')) > now()`. Beachte `| string`: YAML macht aus `2027-01-31` ein Datumsobjekt. `to_datetime` liefert Mitternacht am Tagesanfang, also ist `expires` der erste Tag, an dem die Ausnahme nicht mehr gilt.

## Hinweis 2

Berechne `cis_exception_ids: "{{ cis_exceptions | map(attribute='id') | list }}"`. Umschließe jede Kontrolle mit einem `block:` mit `when: cis_level | int >= N and 'id' not in cis_exception_ids` - Blöcke geben `when` an jeden Task darin weiter. Task-Namen im Block beginnen mit der ID.

## Hinweis 3

Die `tasks/main.yml` der Rolle als Gerüst - setze jedes `"..."` ein:

```yaml
- name: Preflight | profile level is 1 or 2
  ansible.builtin.assert:
    that: "..."                       # der Level als Zahl: | int
    fail_msg: "..."
    quiet: true

- name: Preflight | every exception is known, justified and not expired
  ansible.builtin.assert:
    that:
      - "..."                         # bekannte ID
      - "..."                         # Begründung ist nicht leer
      - "..."                         # expires ist gesetzt
      - "..."                         # expires liegt in der Zukunft
    fail_msg: "..."
    quiet: true
  loop: "{{ cis_exceptions | default([]) }}"
  loop_control:
    label: "{{ item.id | default('?') }}"

- name: Preflight | collect exception ids
  ansible.builtin.set_fact:
    cis_exception_ids: "..."          # Hinweis 2

- name: Preflight | show active exceptions
  ansible.builtin.debug:
    msg: "..."                        # ID, Ablaufdatum und Begründung
  loop: "{{ cis_exceptions | default([]) }}"
  loop_control:
    label: "{{ item.id }}"

- name: L1-telnet | Insecure client packages
  when: "..."                         # ID nicht in den Ausnahmen
  block:
    - name: L1-telnet | Remove telnet
      ansible.builtin.package:
        name: telnet
        state: absent

- name: L1-ssh-maxauthtries | SSH authentication attempts
  when: "..."
  block:
    - name: L1-ssh-maxauthtries | Limit authentication attempts
      ansible.builtin.copy:
        dest: /etc/ssh/sshd_config.d/01-cis-maxauthtries.conf
        content: "..."
        owner: root
        group: root
        mode: "0600"
        validate: "..."               # Syntaxprüfung der sshd-Konfiguration, %s ist die temporäre Datei

- name: L2-modules | Level 2 kernel modules
  when:
    - "..."                           # Level 2 oder höher, als Zahl
    - "..."                           # ID nicht in den Ausnahmen
  block:
    - name: L2-modules | Disable squashfs and udf
      ansible.builtin.copy:
        dest: "/etc/modprobe.d/cis-{{ item }}.conf"
        content: "..."                # install <Modul> /bin/false und blacklist <Modul>
        owner: root
        group: root
        mode: "0644"
      loop: [squashfs, udf]

- name: L2-audit-identity | Audit identity files
  when:
    - "..."
    - "..."
  block:
    - name: L2-audit-identity | Rules directory
      ansible.builtin.file:
        path: /etc/audit/rules.d
        state: directory
        owner: root
        group: root
        mode: "0750"

    - name: L2-audit-identity | Identity rules
      ansible.builtin.copy:
        dest: /etc/audit/rules.d/50-cis-identity.rules
        content: "..."                # eine Watch-Regel je Identitätsdatei, Key identity
        owner: root
        group: root
        mode: "0640"
```

Die Liste der bekannten IDs gehört in die `vars/` der Rolle. Referenz: `lab solution 4.02`. Was der Check tut: `cat /lab/exercises/stage4-advanced/4.02-*/check.sh`.
