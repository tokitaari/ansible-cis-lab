# 4.10 - Paketsignaturen: jedes Repository geprüft, keine Umgehung

## Hinweis 1

Erst ansehen, nur lesend: `ansible targets -m ansible.builtin.setup -a 'gather_subset=min filter=ansible_pkg_mgr'` zeigt die sechs Werte. Dann suche den alten Mirror auf jedem Host: `/etc/apt/sources.list.d/`, `/etc/yum.repos.d/`, `/etc/zypp/repos.d/`, das Ende von `/etc/pacman.conf`, `/etc/apk/repositories` und `/etc/apk/config`. Frage jeden Manager, was wirksam ist (`apt-config dump`, `dnf5 --dump-repo-config='*'` auf fedora, `zypper --xmlout lr`, `pacman-conf -r <repo> SigLevel`). Die Wahl ist eine Zeile, wie in 4.09: `cis_sig: "{{ cis_sig_by_pkg_mgr[ansible_facts.pkg_mgr] }}"`, abgesichert durch ein `ansible.builtin.assert`; jeder Block hat dann ein `when:` auf `ansible_facts.pkg_mgr`.

## Hinweis 2

- "Hat keinen Schlüssel" ist eine Eigenschaft einer Datei, die du finden kannst: `ansible.builtin.find` mit `contains:` listet die Dateien, die einen Schlüssel nennen, und `| difference(...)` aller Dateien minus dieser lässt die ohne übrig. `contains:` wird ab dem Anfang jeder Zeile verglichen (`re.match`): Beginne ein Muster, das mitten in einer Zeile stehen kann, mit `.*`, und nimm `(?i)` für `Signed-By` / `signed-by`.
- `gpgcheck=0` in den Repository-Dateien zu korrigieren reicht nicht: Ein Repository ohne `gpgkey` kann nichts prüfen, und die README verlangt, es zu entfernen. In den Repository-Dateien, die einen Schlüssel haben, wird `gpgcheck` trotzdem eingeschaltet.
- `[main]` bekommt die Zeile mit `community.general.ini_file` (`no_extra_spaces: true` behält den Stil von `dnf.conf`). fedora hat gar keine Zeile - der Standardwert ist an, aber das Audit liest die Datei.
- pacman: `pacman-conf --repo-list` nennt die Repositories, `pacman-conf -r <repo> SigLevel` gibt nur aus, was ein Repository selbst setzt (leer = global). `community.general.ini_file` mit nur `section:` und `state: absent` entfernt einen ganzen Abschnitt.
- apk: `ansible.builtin.lineinfile` mit `state: absent` entfernt eine Zeile per `regexp:`; ein negativer Lookahead wie `^(?!#)(?!https://)\S` trifft eine Zeile, die weder Kommentar noch https-URL ist.

## Hinweis 3

Die Tasks als Gerüst - fülle jedes `"..."`. Die Daten (`cis_sig_by_pkg_mgr` mit Hauptdatei, Repository-Verzeichnis und Aktualisierungsbefehl je Manager) gehören in `vars:`.

```yaml
- name: The package manager of this host is a known one
  ansible.builtin.assert:
    that: "..."                       # pkg_mgr ist ein Schlüssel des Dicts
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
        contains: "..."               # signed-by= oder Signed-By:
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
      loop: "..."                     # alle - mit Schlüssel, plus trusted
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
        contains: "..."               # zweimal: ohne und mit contains
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
        regexp: "..."                 # gpgcheck oder pkg_gpgcheck = 0/no/false/off
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
      when: "..."                     # PackageOptional, PackageNever oder PackageTrustAll

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

Ein Handler führt den Aktualisierungsbefehl des Managers des Hosts aus (`argv:` aus dem Dict, `changed_when: true`) und hört auf den Namen, den die Tasks benachrichtigen; pacman hat im Dict keinen Aktualisierungsbefehl, dort überspringt der Handler ihn. Referenz: `lab solution 4.10`.
