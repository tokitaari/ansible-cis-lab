# 3.05 - Konten-Audit: UID 0, leere Passwörter, umask, TMOUT

## Hinweis 1

`(passwd.content | b64decode).splitlines() | map('split', ':')` liefert eine Liste von Listen. `selectattr('2', 'equalto', '0')` filtert nach dem dritten Feld (UID); `map(attribute='0')` liefert die Namen. `root` entfernst du mit `reject('equalto', 'root')`.

## Hinweis 2

Leeres Passwort: shadow-Feld 2 (Index `1`) ist `''` → `selectattr('1', 'equalto', '')`. Sperren mit `ansible.builtin.user: name=... password_lock=true`. Entfernen mit `state: absent`, `force: true`, `remove: false`.

## Hinweis 3

```yaml
- name: CIS 5.4 - accounts and environment
  hosts: "..."
  become: "..."
  tasks:
    - name: Read account databases
      ansible.builtin.slurp:
        src: "{{ item }}"
      loop: ["...", "..."]       # passwd, shadow
      register: cis_account_files

    - name: Find dangerous accounts
      ansible.builtin.set_fact:
        cis_uid0_extra: "..."     # Namen mit UID 0 ohne root (Hinweis 1)
        cis_empty_password: "..." # Namen mit leerem shadow-Feld (Hinweis 2)

    - name: Report findings
      ansible.builtin.debug:
        msg: "..."

    - name: Remove additional UID 0 accounts
      ansible.builtin.user:
        name: "{{ item }}"
        state: absent
        force: "..."
        remove: "..."             # das Home nie löschen: es kann /root sein
      loop: "{{ cis_uid0_extra }}"

    - name: Lock accounts with an empty password
      ansible.builtin.user: "..." # password_lock
      loop: "{{ cis_empty_password }}"

    - name: Default umask for login shells
      ansible.builtin.copy: "..." # /etc/profile.d/50-cis-umask.sh, 0644 root:root

    - name: Shell timeout for interactive shells
      ansible.builtin.copy: "..." # 50-cis-tmout.sh: TMOUT, readonly TMOUT, export TMOUT
```

Schreibe `umask 027`, nicht `0027` - der Check akzeptiert nur das erste. Der zweite Lauf findet leere Listen, die Schleifen tun also nichts - Idempotenz geschenkt. Referenz: `lab solution 3.05`.
