# 4.06 - Kontosperre mit pam_faillock (authselect)

## Hinweis 1

Zuerst lesen: `ansible.builtin.command: authselect current` mit `changed_when: false`, `check_mode: false`, `register: cis_authselect`.

## Hinweis 2

`ansible.builtin.command: authselect enable-feature with-faillock` mit `when: "'with-faillock' not in cis_authselect.stdout"` und `changed_when: true`. Konfiguration: `lineinfile` mit `regexp: '^\s*#?\s*deny\s*='` und `line: 'deny = 5'` (die Default-Datei enthält auskommentierte Beispiele).

## Hinweis 3

Referenz: `lab solution 4.06`.
