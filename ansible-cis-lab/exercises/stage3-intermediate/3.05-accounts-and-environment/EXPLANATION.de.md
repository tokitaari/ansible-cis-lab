# 3.05 - Konten-Audit: UID 0, leere Passwörter, umask, TMOUT: Erklärung

### Erst aufklären, dann beheben
```yaml
- name: Find dangerous accounts
  ansible.builtin.set_fact:
    cis_uid0_extra: >-
      {{ (cis_passwd.content | b64decode).splitlines() | map('split', ':')
         | selectattr('2', 'equalto', '0') | map(attribute='0')
         | reject('equalto', 'root') | list }}
```
Jinja macht aus numerischen Attributnamen Listenindizes, `selectattr('2', ...)` filtert
also nach der UID-Spalte. Dateien parsen schlägt Shell-`awk`: es funktioniert auf
allen acht Systemen gleich (busybox, GNU, ...).

### Die userdel-Falle
`userdel` prüft, ob ein Prozess mit der UID des Kontos läuft - bei UID 0 ist das immer
so. `force: true` (`userdel -f`) überspringt die Prüfung. Hier nie mit `remove: true`
kombinieren: das Home eines UID-0-Alias ist oft `/root`.

### Unbekannte Konten sperren, nicht löschen
`guest` könnte von einer Anwendung genutzt werden. Sperren (`!` vor dem Hash) ist
umkehrbar, Löschen nicht. Melden und einen Menschen über das Löschen entscheiden lassen.

### umask und TMOUT
- `umask 027` → neue Dateien `0640`, Verzeichnisse `0750`.
- `readonly TMOUT` verhindert `unset TMOUT`. Es wirkt nur auf interaktive Shells und
  ersetzt nicht sshds `ClientAlive*`-Einstellungen - du brauchst beides.
- `/etc/profile.d/*.sh` lesen Login-Shells von bash, dash, busybox ash. Nutzer anderer
  Shells (zsh, fish) brauchen eigene Dateien - dokumentieren.

### Praxis
In Produktion zuerst den Aufklärungsteil als eigenes Audit-Play laufen lassen (siehe
Stufe 4) und die Funde prüfen - wegen eines Parser-Fehlers auf 2.000 Servern
automatisch Konten zu löschen, ist ein schlechter Tag.

## Musterlösung

Anzeigen mit `lab solution 3.05`, anwenden mit `lab solve 3.05`.
