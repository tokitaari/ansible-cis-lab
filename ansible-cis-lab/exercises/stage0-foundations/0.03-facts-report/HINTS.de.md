# 0.03 - Facts: ein Bericht über acht Distributionen

## Hinweis 1

Zwei Plays: Play 1 zielt auf `targets` und sammelt nur Facts (`tasks: []` reicht). Play 2 läuft auf `localhost` und rendert das Template.

## Hinweis 2

In Play 2 über `groups['targets']` iterieren und `hostvars[host]['ansible_facts']['os_family']` usw. lesen. Fact-Schlüssel: `distribution`, `distribution_version`, `os_family`, `pkg_mgr`, `service_mgr`, `python_version`.

## Hinweis 3

Template-Zeile: `{{ h }},{{ f.distribution }},{{ f.distribution_version }},{{ f.os_family }},{{ f.pkg_mgr }},{{ f.service_mgr }},{{ f.python_version }}` innerhalb von `{% for h in groups['targets'] %}{% set f = hostvars[h]['ansible_facts'] %}`.
