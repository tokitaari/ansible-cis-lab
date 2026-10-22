# 2.04 - Kernelparameter: Netzwerk-Härtung per sysctl

*[English](README.md)*

| Stufe | Schwierigkeit | Zeit | CIS-Bezug | Hosts |
|---|---|---|---|---|
| Stufe 2 - Bausteine | ★★★☆☆ | ~40 Min. | 3.3 Network kernel parameters / 1.5 Process hardening (L1) | `targets` |

**Konzepte:** `ansible.posix.sysctl`, `dict2items`, `namespaced vs global sysctls`, `collections`

## Ziel

Setze die CIS-Netzwerk-Kernelparameter zur Laufzeit *und* dauerhaft - und lerne, welche Parameter ein Container anfassen darf.

## Hintergrund

Netzwerk-sysctls verhindern, dass ein Server sich wie ein Router verhält (Forwarding,
Redirects, Source Routing), und härten gegen Spoofing und SYN-Floods. Sysctls zur
Prozesshärtung (ASLR, Core-Dumps von setuid-Programmen, ptrace) schützen den Speicher.

**Der wichtige Haken:** `net.*`-Parameter gelten *pro Netzwerk-Namespace* - jeder
Container hat seine eigene Kopie, du darfst sie also live setzen. `kernel.*` und `fs.*`
sind **global** - in einem privilegierten Container änderst du damit deinen HOST. Für
diese schreibst du nur die persistente Datei (wirksam nach dem Neustart einer echten
Maschine). Diese Unterscheidung zählt auch in Produktion (Kubernetes, LXC).

## Anforderungen

- [ ] Nutze das Modul `ansible.posix.sysctl` (ein Collection-Modul - FQCN!).
- [ ] Setze und persistiere diese in `/etc/sysctl.d/60-cis-network.conf` (live angewendet):
  `net.ipv4.ip_forward=0`, `net.ipv4.conf.all.send_redirects=0`, `net.ipv4.conf.default.send_redirects=0`, `net.ipv4.conf.all.accept_redirects=0`, `net.ipv4.conf.default.accept_redirects=0`, `net.ipv4.conf.all.secure_redirects=0`, `net.ipv4.conf.default.secure_redirects=0`, `net.ipv4.conf.all.accept_source_route=0`, `net.ipv4.conf.default.accept_source_route=0`, `net.ipv4.conf.all.log_martians=1`, `net.ipv4.conf.default.log_martians=1`, `net.ipv4.icmp_echo_ignore_broadcasts=1`, `net.ipv4.icmp_ignore_bogus_error_responses=1`, `net.ipv4.conf.all.rp_filter=1`, `net.ipv4.conf.default.rp_filter=1`, `net.ipv4.tcp_syncookies=1`
- [ ] Nur **persistieren** (nicht anwenden!) in `/etc/sysctl.d/60-cis-kernel.conf`:
  `kernel.randomize_va_space=2`, `fs.suid_dumpable=0`, `kernel.yama.ptrace_scope=1`
- [ ] Halte die Parameter in zwei Dict-Variablen und iteriere mit `dict2items`.
- [ ] Zweiter Lauf: `changed=0`.

## Vorgehen

```bash
lab start 2.04            # legt /lab/work/2.04/ an
cd /lab/work/2.04
# playbook.yml schreiben, dann ausführen:
ansible-playbook playbook.yml
lab check 2.04            # prüft den Zustand und dass ein zweiter Lauf nichts ändert
```

Festgefahren? `lab hint 2.04 1` (sanft) ... `lab hint 2.04 3` (fast die Lösung).  
Bestanden? Lies `lab explain 2.04` - dort stehen Stolperfallen und Praxis-Hinweise.
Host kaputt? `./lab.sh reset <host>` auf dem Host stellt ihn wieder her.

## Bonus (optional)

- Welche Moduloptionen entscheiden zwischen *live* und *nur Datei*? Lies in `ansible-doc ansible.posix.sysctl` zu `sysctl_set` und `reload`.
- IPv6: ergänze `net.ipv6.conf.all.accept_ra=0` usw. Was passiert, wenn IPv6 im Container deaktiviert ist? Wie machst du den Task robust?
