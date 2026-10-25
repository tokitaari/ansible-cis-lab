# 4.04 - Ansible Vault: Notfall-Admin-Konto

*[English](README.md)*

| Stufe | Schwierigkeit | Zeit | CIS-Bezug | Hosts |
|---|---|---|---|---|
| Stufe 4 - Fortgeschritten | ★★★★☆ | ~60 Min. | 5.4.1 / 5.2 (L1) | `targets:!alpine_family` |

**Konzepte:** `ansible-vault`, `password_hash with stable salt`, `no_log`, `user aging fields`

## Ziel

Lege auf allen Targets außer Alpine ein Notfall-Admin-Konto `cisadmin` an. Sein Passwort liegt verschlüsselt in Git, sein Hash ist stabil (idempotent), und das Konto unterliegt der Passwortalterung.

## Hintergrund

Wenn SSO oder das Automatisierungskonto ausfällt, brauchst du ein "Break-Glass"-Konto.
Sein Passwort darf nie im Klartext stehen - nicht in Git, nicht in Logs, nicht in
`-v`-Ausgaben.

Drei klassische Fehler, die diese Aufgabe vermeidet:
1. Klartext-Geheimnis in `group_vars` → **Ansible Vault**,
2. `password_hash('sha512')` ohne Salt → bei jedem Lauf neues Zufallssalt → jedes Mal
   `changed` (und jeder Lauf ändert den Passwort-Hash!) → **stabiles Salt**,
3. Geheimnisse in der Task-Ausgabe → **`no_log: true`**.

Alpine ist ausgenommen, weil das user-Modul dort busybox-Werkzeuge nutzt, die keine
Alterungsfelder unterstützen.

## Anforderungen

- [ ] `/lab/work/4.04/vault.yml` ist mit `ansible-vault` verschlüsselt und definiert `vault_cisadmin_password`. Das Vault-Passwort liegt in `/lab/work/4.04/.vault-pass` (nur im Lab - niemals committen).
- [ ] Benutzer `cisadmin`: Passwort aus dem Vault, gehasht mit SHA-512 und einem **pro Host stabilen Salt**, `password_expire_max: 365`, `password_expire_min: 1`.
- [ ] `/etc/sudoers.d/60-cisadmin`: `cisadmin ALL=(ALL) ALL` (Passwort erforderlich - kein `NOPASSWD`), `0440`, validiert.
- [ ] Der user-Task nutzt `no_log: true`.
- [ ] Zweiter Lauf: `changed=0`. Check mit Vault-Passwort ausführen: `lab check 4.04 --vault-password-file /lab/work/4.04/.vault-pass`.

## Vorgehen

```bash
lab start 4.04            # legt /lab/work/4.04/ an
cd /lab/work/4.04
# playbook.yml schreiben, dann ausführen:
ansible-playbook playbook.yml
lab check 4.04            # prüft den Zustand und dass ein zweiter Lauf nichts ändert
```

Festgefahren? `lab hint 4.04 1` (sanft) ... `lab hint 4.04 3` (fast die Lösung).  
Bestanden? Lies `lab explain 4.04` - dort stehen Stolperfallen und Praxis-Hinweise.
Host kaputt? `./lab.sh reset <host>` auf dem Host stellt ihn wieder her.

## Bonus (optional)

- Passwort rotieren: `ansible-vault edit vault.yml`, neu ausführen. Genau eine Änderung pro Host?
- Nutze `ansible-vault encrypt_string` für eine einzelne Variable in einer sonst unverschlüsselten Datei. Wann ist welcher Ansatz besser?
- In echten Umgebungen kommt das Vault-Passwort aus einem Skript (`--vault-password-file` darf ausführbar sein), das einen Secret Store fragt. Skizziere eins für Azure Key Vault oder HashiCorp Vault.
