# Container-Grenzen - was das Lab zeigen kann und was nicht

*[English](CONTAINER_LIMITS.md)*

Alle Targets teilen sich **einen Kernel - den deines Hosts**. Container isolieren
*Namespaces*, nicht den Kernel. Damit die meisten CIS-Kontrollen realistisch sind, laufen
die Targets `privileged` mit echtem Init-System. Das bringt Verantwortung mit sich: manche
Aktionen in einem Target ändern deinen Host.

## Regeln, die im ganzen Lab gelten

| Im Target niemals | Warum | Was die Aufgaben stattdessen tun |
|---|---|---|
| `modprobe -r`, `rmmod`, Module laden | Module gehören dem Host-Kernel | nur `/etc/modprobe.d` schreiben (2.03) |
| `sysctl -w kernel.*` / `fs.*`, `sysctl -p` auf solche Dateien | nicht namespaced → ändert den Host | nur persistieren; `reload: false` (2.04) |
| `auditd` starten, `auditctl`, `augenrules --load` | das Audit-Subsystem ist global | nur Regeln konfigurieren (3.04) |
| Uhr stellen (chrony/ntpd mit CAP_SYS_TIME) | ändert die Host-Uhr | nicht Teil der Aufgaben |
| `nft flush ruleset` | löscht Dockers DNS-Regeln im Container-Namespace | eigene Tabelle `inet cis_filter` (4.07) |

Die Inventarvariable `lab_in_container: true` (in `ansible/inventory/group_vars/all.yml`)
ist der Schalter, den die Musterlösungen nutzen. Derselbe Code erledigt auf echten VMs die
volle Arbeit.

## Welche CIS-Bereiche hier realistisch sind

| Bereich | Im Lab | Hinweis |
|---|---|---|
| Pakete, Dienste, cron, Banner | voll | |
| SSH, sudo, PAM, Passwortrichtlinie, Konten | voll | echte PAM-Stacks, echter sshd |
| Netzwerk-sysctls (`net.*`) | voll | pro Netzwerk-Namespace |
| Host-Firewall (nftables) | voll | im Netzwerk-Namespace des Containers |
| Dateirechte, AIDE | voll | AIDE scannt das Container-Dateisystem |
| Kernelmodule, sysctls zur Prozesshärtung | nur Konfiguration | Wirkung ist hostweit |
| auditd | nur Konfiguration | Wirkung ist hostweit |
| Getrennte Partitionen, Mount-Optionen | nicht möglich | braucht Blockgeräte / eine VM |
| Bootloader (GRUB-Passwort, Rechte) | nicht möglich | Container booten nicht über GRUB |
| SELinux / AppArmor im Enforcing | nicht möglich | das LSM gehört dem Host-Kernel |
| Zeitsynchronisation | nicht möglich | würde die Host-Uhr ändern |

## Nebenwirkungen, die dir auffallen könnten

- `systemd-sysctl.service` in den Targets wendet `/etc/sysctl.d` beim Containerstart an. Nach
  Aufgabe 2.04 gehören dazu die `kernel.*`-Werte aus `60-cis-kernel.conf` (ASLR=2,
  suid_dumpable=0, ptrace_scope=1). Das sind Härtungswerte und auf modernen Hosts meist schon
  Standard; wenn du das vermeiden willst, maskiere die Unit in den Target-Images
  (`systemctl mask systemd-sysctl.service` in `targets/common/bootstrap.sh`).
- Privilegierte Container sehen Host-Geräte. Nichts in den Aufgaben fasst sie an.

## Das volle Bild?

Die Rollen laufen unverändert auf VMs: setze in deinem eigenen Inventar
`lab_in_container: false`, und die geschützten Tasks (Module entladen, globale sysctls,
auditd-Dienst) werden aktiv. Eine Vagrant/libvirt- oder Cloud-VM pro Distribution ist der
natürliche nächste Schritt nach dem Lab.
