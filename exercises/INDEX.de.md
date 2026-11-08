# Aufgabenübersicht

Die Spalte *Lektion* nennt die Lektion(en), die die Aufgabe vorbereiten: vorher lesen mit
`lab lesson <id>` (zum Beispiel `lab lesson 2.03`).

## Stufe 0 - Grundlagen

| ID | Titel | Schwierigkeit | Zeit | CIS | Hosts | Lektion |
|---|---|---|---|---|---|---|
| 0.01 | [Rundgang: Inventar und Erreichbarkeit](stage0-foundations/0.01-lab-tour/README.de.md) | ★☆☆☆☆ | ~15 min | - | `targets` | [L00](../docs/lessons/L00-lab-and-ansible-basics.de.md) |
| 0.02 | [Python auf Alpine per raw nachrüsten](stage0-foundations/0.02-bootstrap-alpine/README.de.md) | ★☆☆☆☆ | ~20 min | - | `alpine_family` | [L00](../docs/lessons/L00-lab-and-ansible-basics.de.md) |
| 0.03 | [Facts: ein Bericht über acht Distributionen](stage0-foundations/0.03-facts-report/README.de.md) | ★★☆☆☆ | ~30 min | - | `targets` | [L00](../docs/lessons/L00-lab-and-ansible-basics.de.md) |
| 0.04 | [Erstes Härtungs-Playbook: SSH-Warnbanner](stage0-foundations/0.04-first-playbook-banner/README.de.md) | ★☆☆☆☆ | ~20 min | 1.6 Command line warning banners | `targets` | [L00](../docs/lessons/L00-lab-and-ansible-basics.de.md) |

## Stufe 1 - Einsteiger

| ID | Titel | Schwierigkeit | Zeit | CIS | Hosts | Lektion |
|---|---|---|---|---|---|---|
| 1.01 | [Unsichere Client-Pakete entfernen](stage1-beginner/1.01-remove-telnet/README.de.md) | ★☆☆☆☆ | ~20 min | 2.2 Client services | `targets` | [L02](../docs/lessons/L02-safe-changes.de.md), [L03](../docs/lessons/L03-base-hardening.de.md) |
| 1.02 | [Rechte auf /etc/passwd und /etc/group](stage1-beginner/1.02-passwd-group-permissions/README.de.md) | ★☆☆☆☆ | ~20 min | 7.1 System file permissions | `targets` | [L02](../docs/lessons/L02-safe-changes.de.md), [L03](../docs/lessons/L03-base-hardening.de.md) |
| 1.03 | [SSH: Root-Login und leere Passwörter verbieten](stage1-beginner/1.03-ssh-root-login/README.de.md) | ★★☆☆☆ | ~35 min | 5.1 SSH server | `targets` | [L02](../docs/lessons/L02-safe-changes.de.md), [L03](../docs/lessons/L03-base-hardening.de.md) |
| 1.04 | [FTP-Server stoppen und deaktivieren](stage1-beginner/1.04-disable-ftp-server/README.de.md) | ★★☆☆☆ | ~25 min | 2.1 Server services | `targets` | [L02](../docs/lessons/L02-safe-changes.de.md), [L03](../docs/lessons/L03-base-hardening.de.md) |
| 1.05 | [sudo: PTY erzwingen und in Datei protokollieren](stage1-beginner/1.05-sudo-hardening/README.de.md) | ★★☆☆☆ | ~25 min | 5.2 Configure privilege escalation | `targets` | [L02](../docs/lessons/L02-safe-changes.de.md), [L03](../docs/lessons/L03-base-hardening.de.md) |

## Stufe 2 - Bausteine

| ID | Titel | Schwierigkeit | Zeit | CIS | Hosts | Lektion |
|---|---|---|---|---|---|---|
| 2.01 | [/etc/shadow: richtige Rechte je OS-Familie](stage2-building-blocks/2.01-shadow-permissions-per-family/README.de.md) | ★★☆☆☆ | ~35 min | 7.1 System file permissions | `targets` | [L03](../docs/lessons/L03-base-hardening.de.md), [L04](../docs/lessons/L04-platform-differences-as-data.de.md) |
| 2.02 | [SSH-Server-Härtung mit Jinja2-Template](stage2-building-blocks/2.02-sshd-template/README.de.md) | ★★★☆☆ | ~45 min | 5.1 SSH server | `targets` | [L04](../docs/lessons/L04-platform-differences-as-data.de.md) |
| 2.03 | [Unnötige Kernelmodule deaktivieren](stage2-building-blocks/2.03-disable-kernel-modules/README.de.md) | ★★☆☆☆ | ~30 min | 1.1.1 Kernel modules / 3.2 Network kernel modules | `targets` | [L05](../docs/lessons/L05-kernel-modules-and-sysctl.de.md) |
| 2.04 | [Kernelparameter: Netzwerk-Härtung per sysctl](stage2-building-blocks/2.04-sysctl-network/README.de.md) | ★★★☆☆ | ~40 min | 3.3 Network kernel parameters / 1.5 Process hardening | `targets` | [L05](../docs/lessons/L05-kernel-modules-and-sysctl.de.md) |
| 2.05 | [Job-Scheduler: cron-Rechte und Zugriff](stage2-building-blocks/2.05-cron-hardening/README.de.md) | ★★★☆☆ | ~45 min | 2.4 Job schedulers | `targets` | [L06](../docs/lessons/L06-job-schedulers.de.md) |
| 2.06 | [Alle Login-Banner aus einem Template](stage2-building-blocks/2.06-banners-template-loop/README.de.md) | ★★☆☆☆ | ~25 min | 1.6 Command line warning banners | `targets` | [L04](../docs/lessons/L04-platform-differences-as-data.de.md) |

## Stufe 3 - Mittelstufe

| ID | Titel | Schwierigkeit | Zeit | CIS | Hosts | Lektion |
|---|---|---|---|---|---|---|
| 3.01 | [Alles in eine Rolle überführen](stage3-intermediate/3.01-build-the-cis-role/README.de.md) | ★★★☆☆ | ~90 min | Sections 1, 2, 3, 5, 7 | `targets` | [L07](../docs/lessons/L07-roles-tags-project-structure.de.md) |
| 3.02 | [Passwortalterung und inaktive Konten](stage3-intermediate/3.02-password-aging/README.de.md) | ★★★☆☆ | ~45 min | 5.4.1 Shadow password suite parameters | `targets` | [L08](../docs/lessons/L08-accounts-and-pam.de.md) |
| 3.03 | [Passwortqualität mit pam_pwquality](stage3-intermediate/3.03-password-quality/README.de.md) | ★★★☆☆ | ~45 min | 5.3.3 PAM arguments (pwquality) | `debian_family:redhat_family` | [L08](../docs/lessons/L08-accounts-and-pam.de.md) |
| 3.04 | [auditd: Regeln und Log-Aufbewahrung (Level 2)](stage3-intermediate/3.04-auditd-rules/README.de.md) | ★★★☆☆ | ~50 min | 6.3 Configure auditd | `targets` | [L09](../docs/lessons/L09-auditing-and-integrity.de.md) |
| 3.05 | [Konten-Audit: UID 0, leere Passwörter, umask, TMOUT](stage3-intermediate/3.05-accounts-and-environment/README.de.md) | ★★★☆☆ | ~50 min | 5.4.2 / 5.4.3 User accounts and environment | `targets` | [L08](../docs/lessons/L08-accounts-and-pam.de.md) |

## Stufe 4 - Fortgeschritten

| ID | Titel | Schwierigkeit | Zeit | CIS | Hosts | Lektion |
|---|---|---|---|---|---|---|
| 4.01 | [Reiner Audit-Lauf mit Compliance-Bericht](stage4-advanced/4.01-audit-only-report/README.de.md) | ★★★★☆ | ~75 min | cross-section | `targets` | [L10](../docs/lessons/L10-compliance-reporting.de.md) |
| 4.02 | [Profile (Level 1/2) und dokumentierte Ausnahmen](stage4-advanced/4.02-profiles-and-exceptions/README.de.md) | ★★★★☆ | ~75 min | framework | `debian` | [L11](../docs/lessons/L11-profiles-exceptions-and-data-driven-roles.de.md) |
| 4.03 | [Datengetriebene Rolle für alle Plattformen (inkl. Alpine)](stage4-advanced/4.03-data-driven-multi-platform-role/README.de.md) | ★★★★☆ | ~120 min | Sections 1-7 | `targets` | [L11](../docs/lessons/L11-profiles-exceptions-and-data-driven-roles.de.md) |
| 4.04 | [Ansible Vault: Notfall-Admin-Konto](stage4-advanced/4.04-vault-break-glass-account/README.de.md) | ★★★★☆ | ~60 min | 5.4.1 / 5.2 | `targets:!alpine_family` | [L12](../docs/lessons/L12-secrets-with-ansible-vault.de.md) |
| 4.05 | [Custom Facts: Hosts beschreiben ihre eigene Härtung](stage4-advanced/4.05-custom-facts/README.de.md) | ★★★☆☆ | ~45 min | (operations) | `targets` | [L10](../docs/lessons/L10-compliance-reporting.de.md) |
| 4.06 | [Kontosperre mit pam_faillock (authselect)](stage4-advanced/4.06-faillock-authselect/README.de.md) | ★★★★☆ | ~45 min | 5.3.2 / 5.3.3.1 pam_faillock | `redhat_family` | [L08](../docs/lessons/L08-accounts-and-pam.de.md) |
| 4.07 | [Host-Firewall mit nftables - sicherer Rollout](stage4-advanced/4.07-nftables-safe-rollout/README.de.md) | ★★★★★ | ~90 min | 4 Host based firewall | `targets:!suse_family` | [L13](../docs/lessons/L13-host-firewall-nftables.de.md) |
| 4.08 | [Dateiintegrität mit AIDE - lang laufende Tasks](stage4-advanced/4.08-aide-async/README.de.md) | ★★★★☆ | ~60 min | 6.1 Filesystem integrity checking | `debian_family:redhat_family` | [L09](../docs/lessons/L09-auditing-and-integrity.de.md) |

## Stufe 5 - Abschlussprojekt

| ID | Titel | Schwierigkeit | Zeit | CIS | Hosts | Lektion |
|---|---|---|---|---|---|---|
| 5.01 | [Abschlussprojekt: CIS-Rolle mit Audit- und Enforce-Modus](stage5-capstone/5.01-capstone-cis-role/README.de.md) | ★★★★★ | ~240 min | Sections 1-7 | `targets` | [L10](../docs/lessons/L10-compliance-reporting.de.md) |
| 5.02 | [Rollout-Strategie: Vorabprüfung, Canary, Wellen](stage5-capstone/5.02-rollout-strategy/README.de.md) | ★★★★★ | ~90 min | (operations) | `targets` | [L14](../docs/lessons/L14-production-rollout.de.md) |
| 5.03 | [Review: deine Rolle vs. eine Community-CIS-Rolle](stage5-capstone/5.03-compare-with-community-role/README.de.md) | ★★★★☆ | ~90 min | all | `(reading)` | [L14](../docs/lessons/L14-production-rollout.de.md) |
