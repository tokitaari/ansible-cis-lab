# 0.03 - Facts: ein Bericht über acht Distributionen: Erklärung

### Warum zwei Plays
Facts werden *pro Host* gesammelt. Der Bericht braucht *alle* an einer Stelle.
Play 1 füllt `hostvars`, Play 2 auf `localhost` liest sie. (`run_once` +
`delegate_to: localhost` in einem Play geht auch, zwei Plays sind aber klarer.)

### Was du sehen solltest
| os_family | pkg_mgr | service_mgr |
|---|---|---|
| Debian | apt | systemd |
| RedHat | dnf (EL) / dnf5 (Fedora) | systemd |
| Suse | zypper | systemd |
| Archlinux | pacman | systemd |
| Alpine | apk | openrc |

Beachte Fedoras `dnf5`: eine Familie, zwei Paketmanager. Genau deshalb ist
`ansible.builtin.package` (delegiert an das passende Modul) so wertvoll.

### Template-Tipps
- Das `template`-Modul rendert mit `trim_blocks=True`, `{% ... %}`-Zeilen hinterlassen
  also keine Leerzeilen.
- `f.get('distribution', 'unreachable')` statt `f.distribution` übersteht fehlende
  Facts (Bonus).
- `{% for h in groups['targets'] | sort %}` liefert stabile Ausgabe → idempotente Datei.

### Praxis
Mit derselben Technik entstehen Inventarberichte, Patchstand-Übersichten oder die
Compliance-Berichte, die du in Stufe 4 baust.

## Musterlösung

Anzeigen mit `lab solution 0.03`, anwenden mit `lab solve 0.03`.
