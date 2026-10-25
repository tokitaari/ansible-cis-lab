# 0.03 - Facts: one report across eight distributions: Explanation

### Why two plays
Facts are gathered *per host*. The report needs *all* of them in one place.
Play 1 fills `hostvars`, play 2 on `localhost` reads them. (`run_once` +
`delegate_to: localhost` inside one play also works, but two plays are clearer.)

### What you should see
| os_family | pkg_mgr | service_mgr |
|---|---|---|
| Debian | apt | systemd |
| RedHat | dnf (EL) / dnf5 (Fedora) | systemd |
| Suse | zypper | systemd |
| Archlinux | pacman | systemd |
| Alpine | apk | openrc |

Note Fedora's `dnf5`: one family, two package managers. That is why
`ansible.builtin.package` (which delegates to the right module) is valuable.

### Template tips
- The `template` module renders with `trim_blocks=True`, so `{% ... %}` lines do not
  leave blank lines.
- `f.get('distribution', 'unreachable')` instead of `f.distribution` survives
  missing facts (bonus).
- `{% for h in groups['targets'] | sort %}` gives stable output → idempotent file.

### Real world
The same technique produces inventory reports, patch-level overviews or the
compliance reports you will build in stage 4.

## Reference solution

Show it with `lab solution 0.03`, apply it with `lab solve 0.03`.
