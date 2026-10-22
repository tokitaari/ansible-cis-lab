# 0.03 - Facts: one report across eight distributions

## Hint 1

Two plays: play 1 targets `targets` and just gathers facts (`tasks: []` is fine). Play 2 runs on `localhost` and renders the template.

## Hint 2

In play 2, iterate over `groups['targets']` and read `hostvars[host]['ansible_facts']['os_family']` etc. Fact keys: `distribution`, `distribution_version`, `os_family`, `pkg_mgr`, `service_mgr`, `python_version`.

## Hint 3

Template line: `{{ h }},{{ f.distribution }},{{ f.distribution_version }},{{ f.os_family }},{{ f.pkg_mgr }},{{ f.service_mgr }},{{ f.python_version }}` inside `{% for h in groups['targets'] %}{% set f = hostvars[h]['ansible_facts'] %}`.
