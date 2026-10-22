# 3.03 - Passwortqualität mit pam_pwquality

## Hinweis 1

Das Drop-in aus einem Dict templaten: `{% for k, v in cis_pwquality.items() %}{{ k }} = {{ v }}\n{% endfor %}` plus eine feste Zeile `enforce_for_root` (ein Flag ohne Wert).

## Hinweis 2

Für die PAM-Prüfung: Stack-Datei per `slurp` lesen, dann bedingt `command: pam-auth-update --enable pwquality`, wenn `'pam_pwquality' not in content`. Auf Red Hat `command: authselect current` mit `changed_when: false` - melde, welches Profil aktiv ist.

## Hinweis 3

Nutze ein Dict für die Stack-Datei pro Familie: `{Debian: /etc/pam.d/common-password, RedHat: /etc/pam.d/system-auth}`. Referenz: `lab solution 3.03`.
