# Exercise index


## Stage 0 - Foundations

| ID | Title | Difficulty | Time | CIS | Hosts |
|---|---|---|---|---|---|
| 0.01 | [Lab tour: inventory and connectivity](stage0-foundations/0.01-lab-tour/README.md) | ★☆☆☆☆ | ~15 min | - | `targets` |
| 0.02 | [Bootstrap Python on Alpine with raw](stage0-foundations/0.02-bootstrap-alpine/README.md) | ★☆☆☆☆ | ~20 min | - | `alpine_family` |
| 0.03 | [Facts: one report across eight distributions](stage0-foundations/0.03-facts-report/README.md) | ★★☆☆☆ | ~30 min | - | `targets` |
| 0.04 | [First hardening playbook: SSH warning banner](stage0-foundations/0.04-first-playbook-banner/README.md) | ★☆☆☆☆ | ~20 min | 1.6 Command line warning banners | `targets` |

## Stage 1 - Beginner

| ID | Title | Difficulty | Time | CIS | Hosts |
|---|---|---|---|---|---|
| 1.01 | [Remove insecure client packages](stage1-beginner/1.01-remove-telnet/README.md) | ★☆☆☆☆ | ~20 min | 2.2 Client services | `targets` |
| 1.02 | [Permissions on /etc/passwd and /etc/group](stage1-beginner/1.02-passwd-group-permissions/README.md) | ★☆☆☆☆ | ~20 min | 7.1 System file permissions | `targets` |
| 1.03 | [SSH: forbid root login and empty passwords](stage1-beginner/1.03-ssh-root-login/README.md) | ★★☆☆☆ | ~35 min | 5.1 SSH server | `targets` |
| 1.04 | [Stop and disable the FTP server](stage1-beginner/1.04-disable-ftp-server/README.md) | ★★☆☆☆ | ~25 min | 2.1 Server services | `targets` |
| 1.05 | [sudo: use a PTY and log to a file](stage1-beginner/1.05-sudo-hardening/README.md) | ★★☆☆☆ | ~25 min | 5.2 Configure privilege escalation | `targets` |

## Stage 2 - Building blocks

| ID | Title | Difficulty | Time | CIS | Hosts |
|---|---|---|---|---|---|
| 2.01 | [/etc/shadow: correct permissions per OS family](stage2-building-blocks/2.01-shadow-permissions-per-family/README.md) | ★★☆☆☆ | ~35 min | 7.1 System file permissions | `targets` |
| 2.02 | [SSH server hardening with a Jinja2 template](stage2-building-blocks/2.02-sshd-template/README.md) | ★★★☆☆ | ~45 min | 5.1 SSH server | `targets` |
| 2.03 | [Disable unneeded kernel modules](stage2-building-blocks/2.03-disable-kernel-modules/README.md) | ★★☆☆☆ | ~30 min | 1.1.1 Kernel modules / 3.2 Network kernel modules | `targets` |
| 2.04 | [Kernel parameters: network hardening via sysctl](stage2-building-blocks/2.04-sysctl-network/README.md) | ★★★☆☆ | ~40 min | 3.3 Network kernel parameters / 1.5 Process hardening | `targets` |
| 2.05 | [Job schedulers: cron permissions and access](stage2-building-blocks/2.05-cron-hardening/README.md) | ★★★☆☆ | ~45 min | 2.4 Job schedulers | `targets` |
| 2.06 | [All login banners from one template](stage2-building-blocks/2.06-banners-template-loop/README.md) | ★★☆☆☆ | ~25 min | 1.6 Command line warning banners | `targets` |

## Stage 3 - Intermediate

| ID | Title | Difficulty | Time | CIS | Hosts |
|---|---|---|---|---|---|
| 3.01 | [Refactor everything into a role](stage3-intermediate/3.01-build-the-cis-role/README.md) | ★★★☆☆ | ~90 min | Sections 1, 2, 3, 5, 7 | `targets` |
| 3.02 | [Password aging and inactive accounts](stage3-intermediate/3.02-password-aging/README.md) | ★★★☆☆ | ~45 min | 5.4.1 Shadow password suite parameters | `targets` |
| 3.03 | [Password quality with pam_pwquality](stage3-intermediate/3.03-password-quality/README.md) | ★★★☆☆ | ~45 min | 5.3.3 PAM arguments (pwquality) | `debian_family:redhat_family` |
| 3.04 | [auditd: rules and log retention (Level 2)](stage3-intermediate/3.04-auditd-rules/README.md) | ★★★☆☆ | ~50 min | 6.3 Configure auditd | `targets` |
| 3.05 | [Account audit: UID 0, empty passwords, umask, TMOUT](stage3-intermediate/3.05-accounts-and-environment/README.md) | ★★★☆☆ | ~50 min | 5.4.2 / 5.4.3 User accounts and environment | `targets` |

## Stage 4 - Advanced

| ID | Title | Difficulty | Time | CIS | Hosts |
|---|---|---|---|---|---|
| 4.01 | [Audit-only compliance report](stage4-advanced/4.01-audit-only-report/README.md) | ★★★★☆ | ~75 min | cross-section | `targets` |
| 4.02 | [Profiles (Level 1/2) and documented exceptions](stage4-advanced/4.02-profiles-and-exceptions/README.md) | ★★★★☆ | ~75 min | framework | `debian` |
| 4.03 | [Data-driven role for all platforms (incl. Alpine)](stage4-advanced/4.03-data-driven-multi-platform-role/README.md) | ★★★★☆ | ~120 min | Sections 1-7 | `targets` |
| 4.04 | [Ansible Vault: break-glass admin account](stage4-advanced/4.04-vault-break-glass-account/README.md) | ★★★★☆ | ~60 min | 5.4.1 / 5.2 | `targets:!alpine_family` |
| 4.05 | [Custom facts: hosts that describe their own hardening](stage4-advanced/4.05-custom-facts/README.md) | ★★★☆☆ | ~45 min | (operations) | `targets` |
| 4.06 | [Account lockout with pam_faillock (authselect)](stage4-advanced/4.06-faillock-authselect/README.md) | ★★★★☆ | ~45 min | 5.3.2 / 5.3.3.1 pam_faillock | `redhat_family` |
| 4.07 | [Host firewall with nftables - safe rollout](stage4-advanced/4.07-nftables-safe-rollout/README.md) | ★★★★★ | ~90 min | 4 Host based firewall | `targets:!suse_family` |
| 4.08 | [File integrity with AIDE - long-running tasks](stage4-advanced/4.08-aide-async/README.md) | ★★★★☆ | ~60 min | 6.1 Filesystem integrity checking | `debian_family:redhat_family` |

## Stage 5 - Capstone

| ID | Title | Difficulty | Time | CIS | Hosts |
|---|---|---|---|---|---|
| 5.01 | [Capstone: CIS role with audit and enforce mode](stage5-capstone/5.01-capstone-cis-role/README.md) | ★★★★★ | ~240 min | Sections 1-7 | `targets` |
| 5.02 | [Rollout strategy: preflight, canary, batches](stage5-capstone/5.02-rollout-strategy/README.md) | ★★★★★ | ~90 min | (operations) | `targets` |
| 5.03 | [Review: your role vs. a community CIS role](stage5-capstone/5.03-compare-with-community-role/README.md) | ★★★★☆ | ~90 min | all | `(reading)` |
