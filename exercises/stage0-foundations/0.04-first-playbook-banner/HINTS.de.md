# 0.04 - Erstes Härtungs-Playbook: SSH-Warnbanner

## Hinweis 1

Das Modul ist `ansible.builtin.copy`. Mit `content:` schreibt es eine Datei aus einem Inline-String.

## Hinweis 2

Setze `owner`, `group` und `mode`. Den Modus als *String in Anführungszeichen*: `mode: "0644"`.

## Hinweis 3

Das Play als Gerüst - fülle jedes `"..."` aus.

```yaml
- name: Set a neutral SSH warning banner
  hosts: "..."                      # alle Targets
  become: "..."                     # /etc gehört root
  tasks:
    - name: Write /etc/issue.net without OS information
      ansible.builtin.copy:
        dest: "..."
        content: "..."              # eine Warnung mit 'authorized', ohne Escapes, ohne Distributionsname
        owner: "..."
        group: "..."
        mode: "..."                 # in Anführungszeichen, vier Ziffern
```

Referenz: `lab solution 0.04`.
