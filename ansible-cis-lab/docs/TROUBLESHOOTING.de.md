# Fehlerbehebung

*[English](TROUBLESHOOTING.md)*

| Symptom | Ursache | Lösung |
|---|---|---|
| Ein systemd-Target beendet sich sofort / `Failed to mount cgroup` | cgroup-Setup deines Docker-Hosts | cgroup v2 nutzen (Standard in aktuellem Docker Desktop/WSL2). Ausweg pro Target in `compose.yaml`: `cgroup: host` und Volume `/sys/fs/cgroup:/sys/fs/cgroup:rw` |
| `rocky`/`alma` scheitern mit `Fatal glibc error: CPU does not support x86-64-v2/v3` | Enterprise Linux 10 braucht eine x86-64-v3-CPU | neuere CPU oder Basis-Image wechseln: `BASE_IMAGE=rockylinux/rockylinux:9` / `almalinux:9` (Build-Arg im Dockerfile) |
| `UNREACHABLE` direkt nach `./lab.sh up` | Targets booten noch / Schlüssel noch nicht installiert | 30 s warten; `./lab.sh logs debian`; im Target `systemctl status lab-keysync` |
| Alle Hosts `UNREACHABLE` nach einer Aufgabe | sshd- oder Firewall-Änderung hat dich ausgesperrt | `./lab.sh reset all` (oder den einzelnen Host), Playbook korrigieren, `validate` und Totmannschalter nutzen |
| `sshd -t` scheitert mit `Bad SSH2 KexAlgorithms` | ein älteres OpenSSH kennt `mlkem768x25519-sha256` nicht | aus der Liste entfernen (2.02 / Rollen-Defaults) - alle aktuellen Lab-Images unterstützen es |
| Viele Checks scheitern nur auf `alpine` | Python fehlt | nach jedem `reset alpine` einmal Aufgabe 0.02 oder `lab solve 0.02` ausführen |
| `ansible.cfg` ignoriert, falsches Inventar | Lab liegt auf einem für alle beschreibbaren Mount (z. B. `/mnt/c` in WSL) | im Linux-Dateisystem klonen; `ANSIBLE_CONFIG` ist im Control Node ohnehin gesetzt |
| Dateien in `./work` gehören auf dem Host root | ohne `lab.sh` gestartet | mit `./lab.sh up` starten (setzt `LAB_UID`/`LAB_GID`) oder `LAB_UID=$(id -u) LAB_GID=$(id -g) docker compose up -d` |
| `package_facts` scheitert auf Fedora/openSUSE | `python3-rpm` fehlt | Image neu bauen (`./lab.sh destroy && ./lab.sh up`); auf openSUSE heißt das Paket evtl. anders (`python313-rpm`) |
| `Fedora 45` gewünscht | das Image-Tag ist `fedora:44`, solange 45 nicht veröffentlicht ist | `BASE_IMAGE` in `targets/fedora/Dockerfile` ändern |
| Image-Pull scheitert bei `archlinux:latest` auf arm64 | kein offizielles arm64-Arch-Image | auf Apple Silicon den Dienst `arch` entfernen oder ein arm64-Community-Image nutzen |
| `lab check` besteht die Zustandsprüfung, meldet aber *not idempotent* | dein Playbook meldet `changed` im `--check` | die als `changed` gelisteten Tasks ansehen; typisch: `command` ohne `changed_when`, `copy` mit Zeitstempeln, `password_hash` ohne Salt |
| Docker-DNS im Target kaputt (`apt`/`dnf` lösen nicht auf) | `nft flush ruleset` oder neu gestarteter nftables-Dienst | `./lab.sh reset <host>`; siehe 4.07 |

## Nützliche Befehle

```bash
./lab.sh ps                         # Container-Status
./lab.sh logs rocky                 # Boot-Log eines Targets
docker compose exec rocky bash      # root-Shell im Target (umgeht SSH - nur zum Debuggen)
ansible targets -m ansible.builtin.raw -a 'uptime'   # geht auch ohne Python
ansible-playbook playbook.yml -vvv                   # ausführliche Verbindungsdetails
```
