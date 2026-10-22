# 0.01 - Rundgang: Inventar und Erreichbarkeit

## Hinweis 1

`ansible-inventory` kennt `--graph`, `--list` und `--host <name>`. Ad-hoc-Syntax: `ansible <muster> -m <modul> [-a <argumente>]`.

## Hinweis 2

Der fehlerhafte Host beschwert sich über den Python-Interpreter. Schau, welche Distribution es ist und was dort *nicht* installiert ist.

## Hinweis 3

`ansible all -m ansible.builtin.ping` scheitert an `alpine`: es gibt kein `/usr/bin/python3`. `ansible alpine -m ansible.builtin.raw -a 'cat /etc/os-release'` funktioniert, weil `raw` nur einen Befehl per SSH schickt.
