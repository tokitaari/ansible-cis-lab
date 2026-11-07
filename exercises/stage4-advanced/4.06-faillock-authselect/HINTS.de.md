# 4.06 - Kontosperre mit pam_faillock (authselect)

## Hinweis 1

Zuerst lesen: `ansible.builtin.command: authselect current` mit `changed_when: false`, `check_mode: false`, `register: cis_authselect`.

## Hinweis 2

`ansible.builtin.command: authselect enable-feature with-faillock` mit `when: "'with-faillock' not in cis_authselect.stdout"` und `changed_when: true`. Konfiguration: `lineinfile` mit `regexp: '^\s*#?\s*deny\s*='` und `line: 'deny = 5'` (die Default-Datei enthält auskommentierte Beispiele).

## Hinweis 3

Die Tasks des Playbooks als Gerüst - füll jedes `"..."` aus. Die beiden Schwellwerte gehören in ein Dict in `vars:` vor `tasks:`.

```yaml
- name: Read the active authselect configuration
  ansible.builtin.command: authselect current
  register: cis_authselect
  changed_when: "..."                 # Lesen ändert nichts
  check_mode: "..."                   # muss auch unter --check laufen

- name: Enable the with-faillock feature if missing
  ansible.builtin.command: authselect enable-feature with-faillock
  when: "..."                         # das Feature steht noch nicht in der Ausgabe
  changed_when: "..."                 # er läuft nur, wenn er etwas ändert

- name: Configure faillock thresholds
  ansible.builtin.lineinfile:
    path: /etc/security/faillock.conf
    regexp: "..."                     # der Schlüssel, auch wenn er noch auskommentiert ist
    line: "..."                       # Schlüssel = Wert
  loop: "..."                         # deny und unlock_time als Schlüssel/Wert-Paare
```

Referenz: `lab solution 4.06`.
