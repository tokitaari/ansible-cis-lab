# 4.06 - Kontosperre mit pam_faillock (authselect)

*[English](README.md)*

| Stufe | Schwierigkeit | Zeit | CIS-Bezug | Hosts |
|---|---|---|---|---|
| Stufe 4 - Fortgeschritten | ★★★★☆ | ~45 Min. | 5.3.2 / 5.3.3.1 pam_faillock (L1) | `redhat_family` |

**Konzepte:** `authselect features`, `idempotent CLI wrappers`, `faillock.conf`, `lock-out risk analysis`

## Ziel

Sperre Konten nach 5 fehlgeschlagenen Anmeldungen für 15 Minuten in der Red-Hat-Familie - mit `authselect`, nicht durch Bearbeiten von PAM-Dateien.

## Hintergrund

`pam_faillock` zählt fehlgeschlagene Authentifizierungen und sperrt das Konto. Auf
EL/Fedora gehört PAM `authselect`; das Feature heißt `with-faillock`. Einstellungen
stehen in `/etc/security/faillock.conf` (CIS: `deny` ≤ 5, `unlock_time` ≥ 900 oder 0).

Aussperr-Analyse vor dem Start: Ansible authentifiziert sich per SSH-**Schlüssel**.
Betrifft faillock Schlüssel-Logins? (Überlege, welche PAM-Phasen sshd bei
Public-Key-Authentifizierung durchläuft.) Die Antwort entscheidet, ob diese Aufgabe
*dich* aussperren kann.

## Anforderungen

- [ ] `authselect current` zeigt das Feature `with-faillock`. Nur aktivieren, wenn es fehlt (kein bedingungsloser Befehl).
- [ ] `/etc/security/faillock.conf`: `deny = 5`, `unlock_time = 900`.
- [ ] `/etc/pam.d/system-auth` und `/etc/pam.d/password-auth` enthalten `pam_faillock`.
- [ ] Hosts: `redhat_family`. Zweiter Lauf: `changed=0`.

## Vorgehen

```bash
lab start 4.06            # legt /lab/work/4.06/ an
cd /lab/work/4.06
# playbook.yml schreiben, dann ausführen:
ansible-playbook playbook.yml
lab check 4.06            # prüft den Zustand und dass ein zweiter Lauf nichts ändert
```

Festgefahren? `lab hint 4.06 1` (sanft) ... `lab hint 4.06 3` (fast die Lösung).  
Bestanden? Lies `lab explain 4.06` - dort stehen Stolperfallen und Praxis-Hinweise.
Host kaputt? `./lab.sh reset <host>` auf dem Host stellt ihn wieder her.

## Bonus (optional)

- Debian/Ubuntu: schreib ein `pam-auth-update`-Profil (`/usr/share/pam-configs/faillock`) und aktiviere es. Schau dir vorher das Format eines vorhandenen Profils an.
- `faillock --user guest` / `faillock --user guest --reset`: probiere ein paar falsche `su guest`-Versuche (vorher einem Testbenutzer ein Passwort geben).
- Soll root gesperrt werden (`even_deny_root`)? Was sagt CIS, und was ist das Betriebsrisiko?
