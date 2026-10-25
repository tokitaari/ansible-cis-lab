# 3.05 - Konten-Audit: UID 0, leere Passwörter, umask, TMOUT

## Hinweis 1

`(passwd.content | b64decode).splitlines() | map('split', ':')` liefert eine Liste von Listen. `selectattr('2', 'equalto', '0')` filtert nach dem dritten Feld (UID); `map(attribute='0')` liefert die Namen. `root` entfernst du mit `reject('equalto', 'root')`.

## Hinweis 2

Leeres Passwort: shadow-Feld 2 (Index `1`) ist `''` → `selectattr('1', 'equalto', '')`. Sperren mit `ansible.builtin.user: name=... password_lock=true`. Entfernen mit `state: absent`, `force: true`, `remove: false`.

## Hinweis 3

Referenz: `lab solution 3.05`. Beachte: der zweite Lauf findet leere Listen, die Schleifen tun also einfach nichts - Idempotenz geschenkt.
