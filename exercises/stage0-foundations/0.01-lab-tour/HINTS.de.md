# 0.01 - Rundgang: Inventar und Erreichbarkeit

## Hinweis 1

`ansible-inventory` kennt `--graph`, `--list` und `--host <name>`. Ad-hoc-Syntax: `ansible <muster> -m <modul> [-a <argumente>]`.

## Hinweis 2

Der fehlerhafte Host beschwert sich über den Python-Interpreter. Schau, welche Distribution es ist und was dort *nicht* installiert ist.

## Hinweis 3

Die Befehle in der Reihenfolge - ersetze jedes `...`. Der `ping`-Fehler nennt den fehlenden Interpreter; `raw` braucht auf dem Ziel kein Python.

```
ansible-inventory --graph
ansible-inventory --host ...
ansible ... -m ansible.builtin.ping
ansible ... -m ansible.builtin.raw -a '...'
```

Referenz: `lab solution 0.01`.
