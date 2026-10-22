# 0.02 - Python auf Alpine per raw nachrüsten: Erklärung

### Das Muster
```yaml
- name: Bootstrap Python on Alpine
  hosts: alpine_family
  gather_facts: false          # das setup-Modul braucht Python
  become: true
  tasks:
    - name: Install python3 if missing
      ansible.builtin.raw: test -e /usr/bin/python3 || { apk add --no-cache python3 && echo INSTALLED; }
      register: bootstrap
      changed_when: "'INSTALLED' in bootstrap.stdout"
    - name: Verify module execution
      ansible.builtin.ping:
```
- Der Shell-Guard (`test -e ... ||`) macht den *Befehl* idempotent.
- `changed_when` macht die *Meldung* ehrlich. Beides ist nötig.
- `raw` wird im Check-Modus (`--check`) übersprungen - es kann seine Wirkung nicht vorhersagen.

### Stolperfallen
- `gather_facts: false` vergessen → das Play stirbt vor deinem ersten Task.
- Die `raw`-Ausgabe enthält `\r\n` und SSH-Rauschen; mit `in` vergleichen, nicht mit `==`.
- `apk add` ohne `--no-cache` lässt den Index in `/var/cache/apk` liegen.

### Härtungssicht
CIS fordert immer wieder, "unnötige Pakete zu entfernen". Python ist *für Ansible*
notwendig, also eine bewusste Abwägung: dokumentieren. Auf Appliances, wo das nicht
akzeptabel ist, bleibst du bei `raw`/`script` oder nutzt Pull-basierte Werkzeuge.
Auf Alpine sind das ~50 MB zusätzliche Angriffsfläche - klein, aber nicht null.

## Musterlösung

Anzeigen mit `lab solution 0.02`, anwenden mit `lab solve 0.02`.
