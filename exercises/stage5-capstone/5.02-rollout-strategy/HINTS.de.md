# 5.02 - Rollout-Strategie: Vorabprüfung, Canary, Wellen

## Hinweis 1

Vorabprüfungen: `ansible.builtin.command: /usr/sbin/sshd -t` und `/usr/sbin/visudo -c` (beide `changed_when: false`, `check_mode: false`; auf openSUSE endet `visudo -c` wegen `/usr/etc/sudoers` mit 1 - siehe 1.05 - also registrieren und per `failed_when` entscheiden); freier Platz: `df -Pk /` (ebenfalls `changed_when: false`, `check_mode: false`), 4. Feld der letzten Zeile in KiB - nicht aus `ansible_facts.mounts`, dort fehlt der Overlay-Root eines Containers (siehe Erklärung).

## Hinweis 2

Canary-Play: `hosts: "{{ cis_canary | default('debian,rocky') }}"`. Rest: `hosts: "targets:!{{ cis_canary | default('debian,rocky') | replace(',', ':!') }}"`. `serial` und `max_fail_percentage` sind Play-Keywords. Ein Prozentwert in `serial` ist ein Anteil der Hosts des Plays (abgerundet, mindestens einer), nicht der übrigen Hosts.

## Hinweis 3

Das Skelett - ersetze jedes `"..."`:

```yaml
- name: Preflight - every host must be healthy, otherwise nothing happens
  hosts: targets
  become: true
  any_errors_fatal: true
  vars:
    cis_min_free_bytes: "..."        # 200 MB in Byte
  tasks:
    - name: Operator confirmed the rollout
      ansible.builtin.assert:
        that: "..."                  # die Extra-Var; ohne sie muss das Play scheitern
      run_once: true

    - name: Current sshd configuration is valid
      ansible.builtin.command: "..."
      changed_when: false
      check_mode: false

    - name: Current sudo configuration is valid
      ansible.builtin.command: "..."
      register: cis_visudo
      changed_when: false
      check_mode: false
      failed_when: "..."             # openSUSE: nur die Rechte-Meldung zu /usr/etc tolerieren

    - name: Read free space on /
      ansible.builtin.command: "..."
      register: cis_df_root
      changed_when: false
      check_mode: false

    - name: Enough free space on /
      ansible.builtin.assert:
        that: "..."                  # 4. Feld der letzten Zeile, KiB in Byte

- name: Canary
  hosts: "..."                       # Hinweis 2
  become: true
  roles:
    - role: cis
      vars:
        cis_mode: enforce
  post_tasks:
    - name: Post-check | drop the persistent SSH connection
      ansible.builtin.meta: "..."

    - name: Post-check | a fresh login still works
      ansible.builtin.wait_for_connection:
        timeout: "..."

    - name: Post-check | read effective sshd settings
      ansible.builtin.command: "..."
      register: cis_post_sshd
      changed_when: false
      check_mode: false

    - name: Post-check | root login is still disabled
      ansible.builtin.assert:
        that: "..."                  # die Schreibweise des Schlüsselworts ist je Host verschieden

- name: Remaining hosts in growing batches
  hosts: "..."                       # Hinweis 2
  become: true
  serial: "..."                      # ein Host, dann ein Anteil, dann der Rest
  max_fail_percentage: "..."         # beim ersten Fehler stoppen
  roles:
    - role: cis
      vars:
        cis_mode: enforce
  post_tasks: []                     # dieselben vier Nachprüfungs-Tasks; leg sie in eine Datei und binde sie in beiden Plays ein
```

Referenz: `lab solution 5.02` (erwartet die 5.01-Rolle in `/lab/work/roles/cis` oder nutzt die Referenzrolle daneben).
