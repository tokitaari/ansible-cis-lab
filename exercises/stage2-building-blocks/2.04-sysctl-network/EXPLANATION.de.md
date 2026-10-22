# 2.04 - Kernelparameter: Netzwerk-Härtung per sysctl: Erklärung

### Lösung
Siehe `lab solution 2.04` - zwei Dicts, zwei Tasks mit Schleife. Der Kernel-Task:
```yaml
- name: Persist global kernel parameters
  ansible.posix.sysctl:
    name: "{{ item.key }}"
    value: "{{ item.value }}"
    sysctl_file: /etc/sysctl.d/60-cis-kernel.conf
    sysctl_set: "{{ not (lab_in_container | default(false)) }}"
    reload: "{{ not (lab_in_container | default(false)) }}"
  loop: "{{ cis_sysctl_kernel | dict2items }}"
```
Mit `lab_in_container` statt hart codiertem `false` ist derselbe Code auf echten
Servern korrekt.

### Moduloptionen
| Option | Wirkung |
|---|---|
| `sysctl_file` | wohin persistiert wird (`/etc/sysctl.d/*.conf` wird beim Booten gelesen) |
| `sysctl_set: true` | Wert zusätzlich sofort setzen (`sysctl -w`) |
| `reload: true` (Default!) | `sysctl -p <datei>` ausführen - wendet **alles** in der Datei an |

### Warum die Parameter wichtig sind
- `ip_forward=0`, `send_redirects=0` - ein Server ist kein Router.
- `accept_redirects=0`, `secure_redirects=0` - ICMP-Redirects können Verkehr umleiten (MITM).
- `accept_source_route=0` - der Absender darf den Weg nicht vorgeben.
- `rp_filter=1` - Pakete verwerfen, deren Absender nicht zurückroutbar ist (Anti-Spoofing).
- `log_martians=1` - unmögliche Absenderadressen protokollieren.
- `tcp_syncookies=1` - SYN-Floods überstehen.
- `randomize_va_space=2` - volles ASLR; `suid_dumpable=0` - keine Core-Dumps mit
  Geheimnissen; `ptrace_scope=1` - Prozesse können sich nicht an Fremdprozesse hängen.

### Container-Falle im Detail
Docker setzt einige `net.*`-Werte selbst (z. B. `ip_forward`), wenn es den Namespace
anlegt. Ein Container-Neustart setzt alle Live-Werte zurück - nur die Datei in
`/etc/sysctl.d` überlebt, und nur, wenn sie beim Booten jemand anwendet
(`systemd-sysctl.service`). Unter OpenRC wird der `sysctl`-Dienst im Container
übersprungen (`rc_sys=docker`) - deshalb zählt hier der Live-Wert.

### Collections
`ansible.posix.sysctl` ist nicht in ansible-core enthalten. Das Lab-Image installiert das
Community-Paket `ansible`, das es mitbringt. In eigenen Projekten deklarierst du es in
`collections/requirements.yml`.

## Musterlösung

Anzeigen mit `lab solution 2.04`, anwenden mit `lab solve 2.04`.
