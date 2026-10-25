# Aufgabenübersicht


## Stufe 0 - Grundlagen

| ID | Titel | Schwierigkeit | Zeit | CIS | Hosts |
|---|---|---|---|---|---|
| 0.01 | [Rundgang: Inventar und Erreichbarkeit](stage0-foundations/0.01-lab-tour/README.de.md) | ★☆☆☆☆ | ~15 min | - | `targets` |
| 0.02 | [Python auf Alpine per raw nachrüsten](stage0-foundations/0.02-bootstrap-alpine/README.de.md) | ★☆☆☆☆ | ~20 min | - | `alpine_family` |
| 0.03 | [Facts: ein Bericht über acht Distributionen](stage0-foundations/0.03-facts-report/README.de.md) | ★★☆☆☆ | ~30 min | - | `targets` |
| 0.04 | [Erstes Härtungs-Playbook: SSH-Warnbanner](stage0-foundations/0.04-first-playbook-banner/README.de.md) | ★☆☆☆☆ | ~20 min | 1.6 Command line warning banners | `targets` |

## Stufe 1 - Einsteiger

| ID | Titel | Schwierigkeit | Zeit | CIS | Hosts |
|---|---|---|---|---|---|
| 1.01 | [Unsichere Client-Pakete entfernen](stage1-beginner/1.01-remove-telnet/README.de.md) | ★☆☆☆☆ | ~20 min | 2.2 Client services | `targets` |
| 1.02 | [Rechte auf /etc/passwd und /etc/group](stage1-beginner/1.02-passwd-group-permissions/README.de.md) | ★☆☆☆☆ | ~20 min | 7.1 System file permissions | `targets` |
| 1.03 | [SSH: Root-Login und leere Passwörter verbieten](stage1-beginner/1.03-ssh-root-login/README.de.md) | ★★☆☆☆ | ~35 min | 5.1 SSH server | `targets` |
| 1.04 | [FTP-Server stoppen und deaktivieren](stage1-beginner/1.04-disable-ftp-server/README.de.md) | ★★☆☆☆ | ~25 min | 2.1 Server services | `targets` |
| 1.05 | [sudo: PTY erzwingen und in Datei protokollieren](stage1-beginner/1.05-sudo-hardening/README.de.md) | ★★☆☆☆ | ~25 min | 5.2 Configure privilege escalation | `targets` |

## Stufe 2 - Bausteine

| ID | Titel | Schwierigkeit | Zeit | CIS | Hosts |
|---|---|---|---|---|---|
| 2.01 | [/etc/shadow: richtige Rechte je OS-Familie](stage2-building-blocks/2.01-shadow-permissions-per-family/README.de.md) | ★★☆☆☆ | ~35 min | 7.1 System file permissions | `targets` |
| 2.02 | [SSH-Server-Härtung mit Jinja2-Template](stage2-building-blocks/2.02-sshd-template/README.de.md) | ★★★☆☆ | ~45 min | 5.1 SSH server | `targets` |
| 2.03 | [Unnötige Kernelmodule deaktivieren](stage2-building-blocks/2.03-disable-kernel-modules/README.de.md) | ★★☆☆☆ | ~30 min | 1.1.1 Kernel modules / 3.2 Network kernel modules | `targets` |
| 2.04 | [Kernelparameter: Netzwerk-Härtung per sysctl](stage2-building-blocks/2.04-sysctl-network/README.de.md) | ★★★☆☆ | ~40 min | 3.3 Network kernel parameters / 1.5 Process hardening | `targets` |
| 2.05 | [Job-Scheduler: cron-Rechte und Zugriff](stage2-building-blocks/2.05-cron-hardening/README.de.md) | ★★★☆☆ | ~45 min | 2.4 Job schedulers | `targets` |
| 2.06 | [Alle Login-Banner aus einem Template](stage2-building-blocks/2.06-banners-template-loop/README.de.md) | ★★☆☆☆ | ~25 min | 1.6 Command line warning banners | `targets` |

## Stufe 3 - Mittelstufe

| ID | Titel | Schwierigkeit | Zeit | CIS | Hosts |
|---|---|---|---|---|---|
| 3.01 | [Alles in eine Rolle überführen](stage3-intermediate/3.01-build-the-cis-role/README.de.md) | ★★★☆☆ | ~90 min | Sections 1, 2, 3, 5, 7 | `targets` |
| 3.02 | [Passwortalterung und inaktive Konten](stage3-intermediate/3.02-password-aging/README.de.md) | ★★★☆☆ | ~45 min | 5.4.1 Shadow password suite parameters | `targets` |
| 3.03 | [Passwortqualität mit pam_pwquality](stage3-intermediate/3.03-password-quality/README.de.md) | ★★★☆☆ | ~45 min | 5.3.3 PAM arguments (pwquality) | `debian_family:redhat_family` |
| 3.04 | [auditd: Regeln und Log-Aufbewahrung (Level 2)](stage3-intermediate/3.04-auditd-rules/README.de.md) | ★★★☆☆ | ~50 min | 6.3 Configure auditd | `targets` |
| 3.05 | [Konten-Audit: UID 0, leere Passwörter, umask, TMOUT](stage3-intermediate/3.05-accounts-and-environment/README.de.md) | ★★★☆☆ | ~50 min | 5.4.2 / 5.4.3 User accounts and environment | `targets` |

## Stufe 4 - Fortgeschritten

| ID | Titel | Schwierigkeit | Zeit | CIS | Hosts |
|---|---|---|---|---|---|
| 4.01 | [Reiner Audit-Lauf mit Compliance-Bericht](stage4-advanced/4.01-audit-only-report/README.de.md) | ★★★★☆ | ~75 min | cross-section | `targets` |
| 4.02 | [Profile (Level 1/2) und dokumentierte Ausnahmen](stage4-advanced/4.02-profiles-and-exceptions/README.de.md) | ★★★★☆ | ~75 min | framework | `debian` |
| 4.03 | [Datengetriebene Rolle für alle Plattformen (inkl. Alpine)](stage4-advanced/4.03-data-driven-multi-platform-role/README.de.md) | ★★★★☆ | ~120 min | Sections 1-7 | `targets` |
| 4.04 | [Ansible Vault: Notfall-Admin-Konto](stage4-advanced/4.04-vault-break-glass-account/README.de.md) | ★★★★☆ | ~60 min | 5.4.1 / 5.2 | `targets:!alpine_family` |
| 4.05 | [Custom Facts: Hosts beschreiben ihre eigene Härtung](stage4-advanced/4.05-custom-facts/README.de.md) | ★★★☆☆ | ~45 min | (operations) | `targets` |
| 4.06 | [Kontosperre mit pam_faillock (authselect)](stage4-advanced/4.06-faillock-authselect/README.de.md) | ★★★★☆ | ~45 min | 5.3.2 / 5.3.3.1 pam_faillock | `redhat_family` |
| 4.07 | [Host-Firewall mit nftables - sicherer Rollout](stage4-advanced/4.07-nftables-safe-rollout/README.de.md) | ★★★★★ | ~90 min | 4 Host based firewall | `targets:!suse_family` |
| 4.08 | [Dateiintegrität mit AIDE - lang laufende Tasks](stage4-advanced/4.08-aide-async/README.de.md) | ★★★★☆ | ~60 min | 6.1 Filesystem integrity checking | `debian_family:redhat_family` |

## Stufe 5 - Abschlussprojekt

| ID | Titel | Schwierigkeit | Zeit | CIS | Hosts |
|---|---|---|---|---|---|
| 5.01 | [Abschlussprojekt: CIS-Rolle mit Audit- und Enforce-Modus](stage5-capstone/5.01-capstone-cis-role/README.de.md) | ★★★★★ | ~240 min | Sections 1-7 | `targets` |
| 5.02 | [Rollout-Strategie: Vorabprüfung, Canary, Wellen](stage5-capstone/5.02-rollout-strategy/README.de.md) | ★★★★★ | ~90 min | (operations) | `targets` |
| 5.03 | [Review: deine Rolle vs. eine Community-CIS-Rolle](stage5-capstone/5.03-compare-with-community-role/README.de.md) | ★★★★☆ | ~90 min | all | `(reading)` |
