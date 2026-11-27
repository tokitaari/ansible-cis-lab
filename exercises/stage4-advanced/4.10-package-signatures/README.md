# 4.10 - Package signatures: every repository verified, no bypass

*[Deutsch](README.de.md)*

| Stage | Difficulty | Time | CIS reference | Hosts |
|---|---|---|---|---|
| Stage 4 - Advanced | ★★★★☆ | ~60 min | 1.2 Package management (L1) | `targets` |

**Concepts:** `choice by pkg_mgr + assert`, `global switch vs per-repository value`, `reading the values in effect`, `set difference of file lists`, `ini_file sections`

## Goal

Make every package manager in the lab verify what it installs: no repository is trusted without a key of its own, no global switch turns the check off, and the values in effect - not only the lines in your files - say so.

## Background

Every target installs packages over the network, and the signature check is what tells a real
package from a forged one. The benchmark asks that this check is on and that only repositories
with a known key are configured. The targets come with an "internal mirror" that a previous admin
added the quick way - trusted without a key. It is a local, empty repository, so nothing breaks
when it goes, but each package manager hides the bypass in a different place:

| `pkg_mgr` | Hosts | Where the check is switched | Where the key of a repository is named |
|---|---|---|---|
| `apt` | debian, ubuntu | `apt.conf.d` (`Acquire::AllowInsecureRepositories` ...), a source's `trusted=yes` | `Signed-By` of the source |
| `dnf` | rocky, alma | `gpgcheck` in `[main]` of `dnf.conf`, and per repository | `gpgkey=` of the repository |
| `dnf5` | fedora | the same keys (`gpgcheck` is an alias of `pkg_gpgcheck`) | `gpgkey=` |
| `zypper` | opensuse | `gpgcheck` in `[main]` of `zypp.conf`, and per repository | `gpgkey=` |
| `pacman` | arch | `SigLevel` in `[options]`, and per repository section | the pacman keyring (one for all) |
| `apk` | alpine | `/etc/apk/config` (`allow-untrusted`) | the keys in `/etc/apk/keys` (one set for all) |

A repository value wins over the global one, and a default can be on although no file says so.
Lesson L16 shows how each manager reports the values in effect; look at the targets before you
write anything.

## Requirements

- [ ] The per-manager data comes from a dict keyed by `ansible_facts.pkg_mgr`. The play stops with a clear message on a host whose value is not one of the six above.
- [ ] apt: no global switch allows unsigned or insecure repositories (`apt-config dump` shows none set to true), and every source entry - one-line or deb822 - names its own key with `Signed-By` and has no `trusted`/`allow-insecure` option.
- [ ] dnf, dnf5, zypper: `gpgcheck=1` is written in the main section of `dnf.conf` or `zypp.conf`, and every configured repository, enabled or not, checks package signatures in effect and names a `gpgkey`. zypper: the metadata check (`repo_gpgcheck`) is on as well.
- [ ] pacman: every repository requires a trusted package signature in effect (its own `SigLevel`, or the global one when it sets none).
- [ ] apk: no `allow-untrusted` in the global options, and every repository is an `https://` URL.
- [ ] A repository that cannot be verified - it has no key - is removed, not "fixed" by switching its check on. After your play, a metadata refresh succeeds without a signature warning (apt, dnf, zypper, apk). Second run: `changed=0`.

## How to work

```bash
lab start 4.10            # creates /lab/work/4.10/
cd /lab/work/4.10
# write playbook.yml, then run it:
ansible-playbook playbook.yml
lab check 4.10            # verifies the state and that a second run changes nothing
```

Stuck? `lab hint 4.10 1` (gentle) ... `lab hint 4.10 3` (almost the answer).  
Passed? Read `lab explain 4.10` - it covers pitfalls and real-world notes.
Broken a host? `./lab.sh reset <host>` on the host restores it.

## Bonus (optional)

- Turn on the metadata check of dnf (`repo_gpgcheck=1`) on rocky and run `dnf makecache`. What does it verify that `gpgcheck` does not, and what happens with a repository that does not sign its metadata?
- Install a local package without a signature on each family (`dnf install ./x.rpm`, `pacman -U`, `apk add --allow-untrusted`). Which settings (`localpkg_gpgcheck`, `LocalFileSigLevel`) decide, and what are their defaults?
- Add a third-party apt repository the right way: its key in `/etc/apt/keyrings/`, bound to that one source with `Signed-By` (`ansible.builtin.deb822_repository`). Why is a key in `/etc/apt/trusted.gpg.d/` worse?
- Download a package and verify it offline (`rpm -K`, `rpmkeys --checksig`). Which key does it need, and where is it imported?
