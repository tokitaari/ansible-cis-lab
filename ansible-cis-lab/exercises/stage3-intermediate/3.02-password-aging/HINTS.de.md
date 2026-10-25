# 3.02 - Passwortalterung und inaktive Konten

## Hinweis 1

`lineinfile` mit `regexp: '^\s*{{ item.key }}\s'` und `line: "{{ item.key }}\t{{ item.value }}"` ersetzt die aktive Zeile oder hängt eine an. Ein `stat` auf `/etc/login.defs` entscheidet zwischen den beiden Varianten.

## Hinweis 2

Aktuelles ENCRYPT_METHOD: Datei per `slurp` lesen, dann `(content | b64decode | regex_findall('(?m)^\s*ENCRYPT_METHOD\s+(\S+)') | last | default('none'))`. Für `useradd -D`: einmal nur lesend ausführen (`changed_when: false`, `check_mode: false`), dann `useradd -D -f 45` nur `when: "'INACTIVE=45' not in result.stdout_lines"`.

## Hinweis 3

Vollständige Referenz: `lab solution 3.02`. Achte darauf, wie `check_mode: false` an den *Lese*-Tasks `--check`-Läufe aussagekräftig hält.
