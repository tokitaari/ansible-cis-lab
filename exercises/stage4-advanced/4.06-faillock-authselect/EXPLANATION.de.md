# 4.06 - Kontosperre mit pam_faillock (authselect): Erklärung

### Was der Check prüft
`lab check 4.06` führt `check.yml` auf der Red-Hat-Familie aus (rocky, alma, fedora) und dann dein
Playbook noch einmal mit `--check`; erwartet wird `changed=0` (`meta.yml` sagt
`idempotency: true`). `check.yml` liest drei Dateien und prüft:
- in `/etc/security/faillock.conf` liegt das letzte aktive `deny` zwischen 1 und 5, und das letzte
  aktive `unlock_time` ist 0 oder mindestens 900 (eine fehlende Zeile scheitert);
- `pam_faillock` steht in `/etc/pam.d/system-auth` und in `/etc/pam.d/password-auth`.

Nicht geprüft wird: dass `authselect` die Änderung gemacht hat (eine Handänderung besteht - bis
der nächste `authselect`-Lauf sie entfernt), das Feature in `authselect current`, die
`account`-Zeile, `even_deny_root` und `fail_interval`, und dass wirklich gesperrt wird.
`deny = 3` besteht ebenfalls; das README verlangt 5.

### So funktioniert es

#### Ein CLI-Werkzeug idempotent einbinden
Frische Targets starten mit dem authselect-Profil `local` und ohne Features. Gemessen auf allen
drei Hosts: ein zweites `authselect enable-feature with-faillock` gab 0 zurück, schrieb nichts
aus und ließ `system-auth`, `password-auth` und `faillock.conf` unverändert. Der Befehl selbst
kann dir nicht sagen, ob er etwas geändert hat, also gilt das Muster: Zustand lesen
(`authselect current`, mit `changed_when: false` und `check_mode: false`), entscheiden (`when`),
ehrlich melden (`changed_when: true`). Dasselbe Muster wie `useradd -D` in 3.02.

Ist das Feature an, tragen beide Dateien drei Zeilen (gemessen):
```text
auth        required      pam_faillock.so preauth silent
auth        required      pam_faillock.so authfail
account     required      pam_faillock.so
```

#### Warum PAM nicht bearbeiten
`system-auth` und `password-auth` sind symbolische Links nach `/etc/authselect/` (gemessen), und
nach der Lösung meldete `authselect check` `Current configuration is valid.`.
`authselect apply-changes` oder ein Profilwechsel erzeugen beide Dateien neu: eine von Hand
eingefügte `pam_faillock`-Zeile verschwände still - die schlimmste Art von Härtungs-Rückschritt.

#### Auskommentierte Defaults
`faillock.conf` liefert auf allen acht Targets `# deny = 3`, `# fail_interval = 900`,
`# unlock_time = 600` und `# even_deny_root`. Der Regexp `^\s*#?\s*deny\s*=` trifft den Kommentar
und ersetzt ihn an Ort und Stelle: nach der Lösung steht `deny = 5` in Zeile 32 und
`unlock_time = 900` in Zeile 45 - dort, wo die Dokumentation sie erwartet.

#### Schlüssel-Logins und faillock
sshd prüft einen öffentlichen Schlüssel selbst und lässt dafür die PAM-Phase *auth* nicht laufen;
es führt PAM *account* und *session* aus. In der account-Phase verweigert `pam_faillock` nie - im
Quelltext von Linux-PAM gibt sie immer Erfolg zurück. Ein gesperrtes Konto meldet sich also
weiter mit Schlüssel an. Gemessen auf rocky, alma und fedora: sechs falsche Passwortversuche über
den PAM-Dienst `sshd` hinterließen fünf Einträge und sperrten `ansible`; ein Ansible-Ping mit dem
SSH-Schlüssel (ohne Multiplexing, ohne `become`) gelang danach auf allen dreien, und die Zahl der
Einträge fiel auf **0** - die account-Phase hat die Sperre gelöscht.

Ob ein Schlüssel-Login die Einträge löscht, hängt vom PAM-Build ab. Upstream-Linux-PAM 1.7.2
lässt das Löschen aus, wenn die auth-Phase nicht lief (RHEL-32294), und ein Ubuntu-24.04-Host mit
zurückportierter Korrektur behielt die Einträge nach einem Schlüssel-Login (gemessen). Das fedora
des Labs hat `pam-1.7.2-2` und löschte sie trotzdem. Prüf deinen Stand mit
`faillock --user <name>` vor und nach einem Schlüssel-Login.

Was das heißt:
- Deine Automatisierung ist sicher: ein Ansible-Konto mit Schlüssel wird von faillock nie
  ausgesperrt, auch nicht durch falsche `su`-Versuche auf seinen Namen.
- Faillock begrenzt das Raten von Passwörtern. Es hält niemanden mit gültigem Schlüssel auf - ein
  Konto zu deaktivieren ist eine andere Kontrolle.
- Auf Hosts, die die Einträge löschen, setzt jeder Schlüssel-Login des Kontos den Zähler eines
  Angreifers zurück.

#### Root
`even_deny_root` ist per Default aus: Fehlversuche sperren root nie (`faillock.conf(5)`). Ob du es
einschaltest, ist Bonus 3: damit können wiederholte Tippfehler beim Passwort an der Konsole den
letzten Zugang aussperren.

### Hinweise je Familie
| `os_family` | Hosts (PAM) | Zu Beginn | In dieser Übung |
|---|---|---|---|
| RedHat | rocky, alma (1.6.1), fedora (1.7.2) | Profil `local`, keine Features, kein `pam_faillock` im Stack | Feature an, drei Zeilen je Datei; der Schlüssel-Login löschte die Einträge |
| Debian | debian, ubuntu (1.7.0) | Modul installiert, nicht in `common-auth`/`common-account` | Bonus 1 (Profil für `pam-auth-update`) |
| Archlinux | arch (1.7.3) | `pam_faillock` steht schon in `system-auth` (vier Zeilen) | nicht im Umfang |
| Suse, Alpine | opensuse, alpine (1.7.1) | Modul installiert, nicht im Stack | nicht im Umfang |

`faillock.conf` beginnt auf allen acht Hosts mit lauter auskommentierten Einstellungen.

### Stolperfallen und gemessene Fakten
| Symptom | Ursache | Lösung |
|---|---|---|
| Der Check scheitert mit `deny=99` | keine aktive `deny`-Zeile - nur der mitgelieferte Kommentar | der Regexp, der auch `#` trifft |
| Ein gesperrtes Konto meldet sich weiter an | Schlüssel-Logins durchlaufen die auth-Phase nicht | erwartet; das Konto deaktivieren, wenn das das Ziel ist |
| Das richtige Passwort wird abgelehnt | das Konto ist gesperrt | `faillock --user <name> --reset` oder `unlock_time` abwarten |
| `faillock --user <name>` zeigt nichts, trotzdem ist eine Datei entstanden | das Nachschlagen eines vorhandenen Benutzers legt eine leere Eintragsdatei an (L08) | harmlos; nicht als Fehlversuch lesen |
| Die `pam_faillock`-Zeilen sind nach einem Update weg | eine Handänderung an einer authselect-Datei | das Feature mit `authselect` aktivieren |

### Praxis-Hinweise
- Dienstkonten sollten sich nur mit Schlüsseln anmelden; ist Passwort-Anmeldung für sie aus,
  können Sperren sie nicht treffen.
- `fail_interval` (Default 900 Sekunden) ist das Fenster, in dem Fehlversuche gezählt werden.
  Leg es zusammen mit `deny` und `unlock_time` fest, und sag dem Helpdesk, wie entsperrt wird.

### Weiterführend
- Lektion [L08 - Konten und PAM: wer sich anmelden darf, wie und mit welchem Passwort](../../../docs/lessons/L08-accounts-and-pam.de.md): PAM-Phasen, die Werkzeuge, denen der Stack gehört, faillock - die Konzepte vor dieser Übung.
- Übung [3.03 - Passwortqualität mit pam_pwquality](../../stage3-intermediate/3.03-password-quality/README.de.md): dieselbe authselect-Zuständigkeit für pwquality.
- Übung [4.04 - Ansible Vault: Notfall-Admin-Konto](../4.04-vault-break-glass-account/README.de.md): das Konto, das du für den Tag aufhebst, an dem alles andere gesperrt ist.

## Musterlösung

Anzeigen mit `lab solution 4.06`, anwenden mit `lab solve 4.06`.
