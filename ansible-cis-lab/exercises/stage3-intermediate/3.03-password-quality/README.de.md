# 3.03 - Passwortqualität mit pam_pwquality

*[English](README.md)*

| Stufe | Schwierigkeit | Zeit | CIS-Bezug | Hosts |
|---|---|---|---|---|
| Stufe 3 - Mittelstufe | ★★★☆☆ | ~45 Min. | 5.3.3 PAM arguments (pwquality) (L1) | `debian_family:redhat_family` |

**Konzepte:** `per-family packages`, `drop-in configs`, `PAM stacks`, `authselect / pam-auth-update`

## Ziel

Erzwinge starke Passwörter mit `pam_pwquality` auf den Familien Debian und Red Hat - und verstehe, wie jede Familie PAM verdrahtet.

## Hintergrund

CIS-Werte: `minlen = 14`, `minclass = 4` (oder gleichwertige Credits), `maxrepeat = 3`,
`maxsequence = 3`, `dictcheck = 1`, `enforce_for_root`.

Die Konfiguration ist einfach - Drop-ins in `/etc/security/pwquality.conf.d/*.conf`
liest libpwquality auf allen aktuellen Systemen. Spannend ist *PAM*: das Modul muss
wirklich im Password-Stack stehen, und jede Familie verwaltet PAM anders:

| Familie | Paket | Wer bearbeitet PAM |
|---|---|---|
| Debian | `libpam-pwquality` | `pam-auth-update` (Profile in `/usr/share/pam-configs`) |
| RedHat | `libpwquality` | `authselect` (`/etc/pam.d/system-auth` nie von Hand bearbeiten) |
| Suse / Arch / Alpine | verschieden / keins | `pam-config` / manuell / Alpine hat standardmäßig kein PAM |

Umfang dieser Aufgabe: `debian_family:redhat_family`. Die anderen sind Bonus.

## Anforderungen

- [ ] Das richtige Paket pro Familie installieren (Dict-Lookup).
- [ ] `/etc/security/pwquality.conf.d/50-cis.conf` (`root:root`, `0644`) mit den CIS-Werten schreiben, erzeugt aus einer Dict-Variable.
- [ ] Debian-Familie: `pam_pwquality` steht in `/etc/pam.d/common-password` (die Paketinstallation aktiviert es normalerweise - prüfen und das Profil nur bei Fehlen mit `pam-auth-update --enable pwquality` aktivieren).
- [ ] Red-Hat-Familie: `pam_pwquality` steht in `/etc/pam.d/system-auth`; `authselect current` prüfen und PAM-Dateien nicht direkt bearbeiten.
- [ ] Zweiter Lauf: `changed=0`. Die Tasks in deine Rolle aufnehmen (Tag `pam`).

## Vorgehen

```bash
lab start 3.03            # legt /lab/work/3.03/ an
cd /lab/work/3.03
# playbook.yml schreiben, dann ausführen:
ansible-playbook playbook.yml
lab check 3.03            # prüft den Zustand und dass ein zweiter Lauf nichts ändert
```

Festgefahren? `lab hint 3.03 1` (sanft) ... `lab hint 3.03 3` (fast die Lösung).  
Bestanden? Lies `lab explain 3.03` - dort stehen Stolperfallen und Praxis-Hinweise.
Host kaputt? `./lab.sh reset <host>` auf dem Host stellt ihn wieder her.

## Bonus (optional)

- openSUSE: `pam-config --add --pwquality`. Arch: welche PAM-Datei würdest du ändern, und warum ist das riskanter?
- Alpine: kein PAM - welcher Mechanismus erzwingt dort Passwortqualität? (Ist das eine CIS-Lücke, die du als Ausnahme dokumentieren würdest?)
- Teste es: `sudo -u ansible passwd` ist sinnlos (kein Passwort). Leg einen Testbenutzer an und probiere `echo 'test:abc' | chpasswd` - greift pwquality bei `chpasswd`? Warum nicht?
