# 0.04 - Erstes Härtungs-Playbook: SSH-Warnbanner

## Hinweis 1

Das Modul ist `ansible.builtin.copy`. Mit `content:` schreibt es eine Datei aus einem Inline-String.

## Hinweis 2

Setze `owner`, `group` und `mode`. Den Modus als *String in Anführungszeichen*: `mode: "0644"`.

## Hinweis 3

```yaml
- name: Set SSH warning banner
  ansible.builtin.copy:
    dest: /etc/issue.net
    content: |
      Authorized access only. Activity on this system is monitored and logged.
    owner: root
    group: root
    mode: "0644"
```
