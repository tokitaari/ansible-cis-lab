# 3.04 - auditd: Regeln und Log-Aufbewahrung (Level 2)

## Hinweis 1

`loop: "{{ cis_audit_rules | dict2items }}"` → `dest: "/etc/audit/rules.d/50-cis-{{ item.key }}.rules"`. Template-Inhalt: eine `{% for rule in item.value %}`-Schleife mit `{{ rule }}` in einer eigenen Zeile und `{% endfor %}` in der nächsten (in einer Template-Datei ist `item` verfügbar). Nimm echte Zeilenumbrüche: ein buchstäbliches `\n` bleibt im Template zwei Zeichen lang, alle Regeln eines Themas landeten in einer Zeile - der Check merkt das nicht, `augenrules` schon.

## Hinweis 2

`auditd.conf` ist `schlüssel = wert`: `lineinfile` mit `regexp: '^\s*{{ item.key }}\s*='` und `line: "{{ item.key }} = {{ item.value }}"`, Schleife über ein Dict. Schreibe die Werte klein (`keep_logs`): der Check vergleicht Groß-/Kleinschreibung.

## Hinweis 3

Die Tasks des Playbooks als Gerüst - fülle jedes `"..."` aus. Die Variablen (Paket je Familie, das Regel-Dict, die `auditd.conf`-Werte) stehen vor `tasks:`; kopiere die Regelliste aus `lab solution 3.04`, wenn du sie nicht abtippen willst.

```yaml
- name: Look for an apt package index
  ansible.builtin.find:
    paths: "..."
    patterns: "..."                   # die Index-Dateien, *_Packages*
  register: cis_apt_lists
  check_mode: false
  when: "..."                         # nur Debian-Familie

- name: Refresh the apt package index
  ansible.builtin.apt:
    update_cache: true
    cache_valid_time: "..."           # 0, solange keine Index-Datei existiert, sonst ein Tag
  changed_when: false
  check_mode: false                   # apt überspringt die Aktualisierung im Check-Modus
  when: "..."

- name: Install the audit framework
  ansible.builtin.package:
    name: "..."                       # Dict-Lookup je os_family
    state: present

- name: Ensure the rules directory exists
  ansible.builtin.file:
    path: /etc/audit/rules.d
    state: directory
    owner: root
    group: root
    mode: "0750"

- name: Deploy one rule file per topic
  ansible.builtin.template:
    src: "..."                        # Template mit for-Schleife über item.value
    dest: "..."                       # 50-cis-<thema>.rules
    owner: root
    group: root
    mode: "0640"
  loop: "..."                         # das Dict als Liste von Schlüssel/Wert-Paaren
  loop_control:
    label: "{{ item.key }}"

- name: Lock the rule set
  ansible.builtin.copy:
    dest: "..."                       # 99-cis-finalize.rules
    content: "..."
    owner: root
    group: root
    mode: "0640"

- name: Configure log retention and space actions
  ansible.builtin.lineinfile:
    path: /etc/audit/auditd.conf
    regexp: "..."                     # der Schlüssel, Blanks vor dem Gleichheitszeichen erlaubt
    line: "..."
  loop: "..."

- name: Enable and start auditd (real hosts only)
  ansible.builtin.service:
    name: auditd
    state: started
    enabled: true
  when: "..."                         # nicht in einem Lab-Container
```

Referenz: `lab solution 3.04`.
