# 4.01 - Reiner Audit-Lauf mit Compliance-Bericht

## Hinweis 1

Sammle zuerst die Rohdaten (ein Task pro Quelle, alle lesend, `check_mode: false` an `command`-Tasks, damit sie auch unter `--check` laufen). Baue dann die Ergebnisliste in **einem** `set_fact` mit Inline-Bedingungen: `status: "{{ 'pass' if 'telnet' not in ansible_facts.packages else 'fail' }}"`.

## Hinweis 2

Für wirksame sshd-Werte den Parse-Trick aus den Checks wiederverwenden: `sshd -T` → `dict(lines | map('regex_replace', '^(\\S+)\\s+(.*)$', '\\1\\t\\2') | map('split', '\\t'))`. Aggregation: zweites Play auf `localhost`, über `groups['targets']` iterieren, `hostvars[h].cis_results` lesen.

## Hinweis 3

Score: `(pass_count / (pass_count + fail_count) * 100) | round(1)`. JSON schreiben mit `copy: content="{{ report | to_nice_json }}"`. Vollständige Referenz: `lab solution 4.01`.
