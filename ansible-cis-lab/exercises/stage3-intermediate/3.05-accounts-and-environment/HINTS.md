# 3.05 - Account audit: UID 0, empty passwords, umask, TMOUT

## Hint 1

`(passwd.content | b64decode).splitlines() | map('split', ':')` gives a list of lists. `selectattr('2', 'equalto', '0')` filters by the third field (UID); `map(attribute='0')` returns the names. Remove `root` with `reject('equalto', 'root')`.

## Hint 2

Empty password: shadow field 2 (index `1`) is `''` → `selectattr('1', 'equalto', '')`. Lock with `ansible.builtin.user: name=... password_lock=true`. Remove with `state: absent`, `force: true`, `remove: false`.

## Hint 3

Reference: `lab solution 3.05`. Notice that the second run finds empty lists, so the loops simply do nothing - idempotency for free.
