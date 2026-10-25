# 4.07 - Host-Firewall mit nftables - sicherer Rollout

*[English](README.md)*

| Stufe | Schwierigkeit | Zeit | CIS-Bezug | Hosts |
|---|---|---|---|---|
| Stufe 4 - Fortgeschritten | ★★★★★ | ~90 Min. | 4 Host based firewall (L1) | `targets:!suse_family` |

**Konzepte:** `own nft table`, `validate: nft -c`, `dead-man switch with background job`, `reset_connection`, `co-existence with Docker`

## Ziel

Rolle eine eingehende Default-Deny-Firewall mit nftables auf sieben Hosts aus - mit automatischem Rollback, falls du dich aussperrst.

## Hintergrund

Die gefährlichste Härtungsänderung ist die Firewall: eine falsche Regel und jeder Host
ist unerreichbar. Profis nutzen einen **Totmannschalter**: vor dem Aktivieren neuer
Regeln wird ein Rollback geplant; nur wenn danach eine *neue* Verbindung gelingt, wird
der Rollback abgebrochen.

**Kein `flush ruleset`.** Auch andere Komponenten besitzen Regeln - hier Dockers
eingebettetes DNS (NAT-Regeln im Namespace jedes Containers), in Produktion Docker,
Kubernetes, fail2ban, libvirt. Ein Flush löscht sie. Verwalte **deine eigene Tabelle**
(`table inet cis_filter`) und sonst nichts.

openSUSE ist ausgenommen (es nutzt firewalld - Bonus).

## Anforderungen

- [ ] Regelsatz-Template `/etc/cis/nftables-cis.nft`, validiert mit `nft -c -f %s`: Tabelle `inet cis_filter`, Input-Policy `drop`; erlaubt `lo`, `established,related`, ICMP-Echo (ratenbegrenzt) und ICMPv6, SSH (tcp/22) nur aus dem Lab-Subnetz (aus `ansible_facts.default_ipv4` ableiten); `invalid` verwerfen; Forward-Policy `drop`; Output `accept`.
- [ ] Die Datei muss wiederholt ladbar sein: Tabelle deklarieren, löschen, definieren (`table inet cis_filter` / `delete table inet cis_filter` / `table inet cis_filter { ... }`).
- [ ] Nur laden, wenn sich die Datei geändert hat **oder** die Tabelle fehlt (Container-Neustart!).
- [ ] Totmannschalter: vor dem Laden einen Hintergrundjob starten, der die Tabelle nach 60 s löscht. Nach dem Laden `meta: reset_connection` + `wait_for_connection`; dann den Job abbrechen.
- [ ] Persistenz: die nftables-Konfigurationsdatei der Distribution enthält nur `include "/etc/cis/nftables-cis.nft"`; der nftables-Dienst ist aktiviert (**nicht** neu starten - warum?).
- [ ] Zweiter Lauf: `changed=0`.

## Vorgehen

```bash
lab start 4.07            # legt /lab/work/4.07/ an
cd /lab/work/4.07
# playbook.yml schreiben, dann ausführen:
ansible-playbook playbook.yml
lab check 4.07            # prüft den Zustand und dass ein zweiter Lauf nichts ändert
```

Festgefahren? `lab hint 4.07 1` (sanft) ... `lab hint 4.07 3` (fast die Lösung).  
Bestanden? Lies `lab explain 4.07` - dort stehen Stolperfallen und Praxis-Hinweise.
Host kaputt? `./lab.sh reset <host>` auf dem Host stellt ihn wieder her.

## Bonus (optional)

- Mach es absichtlich kaputt: SSH-Quelle auf `10.255.255.0/24` ändern und gegen einen Host ausführen. Beobachte, wie der Rollback dich rettet.
- openSUSE/firewalld: setze dieselbe Absicht mit `ansible.posix.firewalld` um (Zone, Services, Default-Target).
- Ergänze eine Output-Policy (Egress-Filter). Welche ausgehenden Verbindungen braucht ein Server *wirklich*?
