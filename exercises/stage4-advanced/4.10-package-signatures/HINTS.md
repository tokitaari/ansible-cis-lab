# 4.10 - Package signatures: every repository verified, no bypass

## Hint 1

Look first, read-only: `ansible targets -m ansible.builtin.setup -a 'gather_subset=min filter=ansible_pkg_mgr'` shows the six values. Then find the legacy mirror on each host: `/etc/apt/sources.list.d/`, `/etc/yum.repos.d/`, `/etc/zypp/repos.d/`, the end of `/etc/pacman.conf`, `/etc/apk/repositories` and `/etc/apk/config`. Ask each manager what is in effect (`apt-config dump`, `dnf5 --dump-repo-config='*'` on fedora, `zypper --xmlout lr`, `pacman-conf -r <repo> SigLevel`). The choice is one line, as in 4.09: `cis_sig: "{{ cis_sig_by_pkg_mgr[ansible_facts.pkg_mgr] }}"`, guarded by an `ansible.builtin.assert`; every block then has `when:` on `ansible_facts.pkg_mgr`.

## Hint 2

- "Has no key" is a property of a file you can find: `ansible.builtin.find` with `contains:` lists the files that name a key, and `| difference(...)` of all files minus those leaves the ones without. `contains:` is matched from the start of each line (`re.match`): start a pattern that may appear in the middle of a line with `.*`, and use `(?i)` for `Signed-By` / `signed-by`.
- Fixing `gpgcheck=0` in the repository files is not enough: a repository without `gpgkey` cannot verify anything, and the README asks to remove it. The repository files that do have a key still get their `gpgcheck` turned on.
- `[main]` gets the line with `community.general.ini_file` (`no_extra_spaces: true` keeps the style of `dnf.conf`). fedora has no line at all - the default is on, but the audit reads the file.
- pacman: `pacman-conf --repo-list` names the repositories, `pacman-conf -r <repo> SigLevel` prints only what a repository sets itself (empty = global). `community.general.ini_file` with only `section:` and `state: absent` removes a whole section.
- apk: `ansible.builtin.lineinfile` with `state: absent` removes a line by `regexp:`; a negative look-ahead such as `^(?!#)(?!https://)\S` matches a line that is neither a comment nor an https URL.

## Hint 3

The tasks as a skeleton - fill in every `"..."`. The data (`cis_sig_by_pkg_mgr` with the main file, the repository directory and the refresh command per manager) belongs in `vars:`.

```yaml
- name: The package manager of this host is a known one
  ansible.builtin.assert:
    that: "..."                       # pkg_mgr is a key of the dict
    fail_msg: "..."

- name: Apt
  when: "..."
  block:
    - name: All sources
      ansible.builtin.find:
        paths: "..."
        patterns: ["*.list", "*.sources"]
      register: cis_apt_all

    - name: Sources that name their own key
      ansible.builtin.find:
        paths: "..."
        patterns: ["*.list", "*.sources"]
        contains: "..."               # signed-by= or Signed-By:
      register: cis_apt_keyed

    - name: Sources that switch the check off
      ansible.builtin.find:
        paths: "..."
        patterns: ["*.list", "*.sources"]
        contains: "..."               # trusted=yes, Trusted: yes
      register: cis_apt_trusted

    - name: Remove them
      ansible.builtin.file:
        path: "{{ item }}"
        state: absent
      loop: "..."                     # all - keyed, plus trusted
      notify: "..."

- name: Dnf, dnf5 and zypper
  when: "..."
  block:
    - name: Main switch
      community.general.ini_file:
        path: "..."
        section: "..."
        option: "..."
        value: "..."
        no_extra_spaces: true
        mode: "0644"

    - name: Repository files / with a key
      ansible.builtin.find:
        paths: "..."
        patterns: "*.repo"
        contains: "..."               # twice: without and with contains
      register: "..."

    - name: Remove repository files without a key
      ansible.builtin.file:
        path: "{{ item }}"
        state: absent
      loop: "..."
      notify: "..."

    - name: Switch the check on in the others
      ansible.builtin.replace:
        path: "{{ item }}"
        regexp: "..."                 # gpgcheck or pkg_gpgcheck = 0/no/false/off
        replace: "..."
      loop: "..."
      notify: "..."

- name: Pacman
  when: "..."
  block:
    - name: Repositories, then each one's own level
      ansible.builtin.command: "..."  # pacman-conf; changed_when false, check_mode false
      register: "..."

    - name: Remove a section that lowers the package check
      community.general.ini_file:
        path: /etc/pacman.conf
        section: "..."
        state: absent
        create: false
      loop: "..."
      when: "..."                     # PackageOptional, PackageNever or PackageTrustAll

- name: Apk
  when: "..."
  block:
    - name: No allow-untrusted / only https repositories
      ansible.builtin.lineinfile:
        path: "..."
        regexp: "..."
        state: absent
      notify: "..."
```

One handler runs the refresh command of the host's manager (`argv:` from the dict, `changed_when: true`) and listens to the name the tasks notify; pacman has no refresh command in the dict, so the handler skips it there. Reference: `lab solution 4.10`.
