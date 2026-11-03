# 5.02 - Rollout-Strategie: Vorabprüfung, Canary, Wellen

## Hinweis 1

Vorabprüfungen: `ansible.builtin.command: /usr/sbin/sshd -t` und `/usr/sbin/visudo -c` (beide `changed_when: false`, `check_mode: false`; auf openSUSE endet `visudo -c` wegen `/usr/etc/sudoers` mit 1 - siehe 1.05 - also registrieren und per `failed_when` entscheiden); freier Platz: `df -Pk /` (ebenfalls `changed_when: false`, `check_mode: false`), 4. Feld der letzten Zeile in KiB - nicht aus `ansible_facts.mounts`, dort fehlt der Overlay-Root eines Containers (siehe Erklärung).

## Hinweis 2

Canary-Play: `hosts: "{{ cis_canary | default('debian,rocky') }}"`. Rest: `hosts: "targets:!{{ cis_canary | default('debian,rocky') | replace(',', ':!') }}"`. `serial` und `max_fail_percentage` sind Play-Keywords.

## Hinweis 3

Referenz: `lab solution 5.02` (erwartet die 5.01-Rolle in `/lab/work/roles/cis` oder nutzt die Referenzrolle daneben).
