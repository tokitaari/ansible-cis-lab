# 3.02 - Passwortalterung und inaktive Konten

## Hinweis 1

`lineinfile` mit `regexp: '^\s*{{ item.key }}\s'` und `line: "{{ item.key }}\t{{ item.value }}"` ersetzt die aktive Zeile oder hängt eine an. Ein `stat` auf `/etc/login.defs` entscheidet zwischen den beiden Varianten.

## Hinweis 2

Aktuelles ENCRYPT_METHOD: Datei per `slurp` lesen, dann `(content | b64decode | regex_findall('(?m)^\s*ENCRYPT_METHOD\s+(\S+)') | last | default('none'))`. Für `useradd -D`: einmal nur lesend ausführen (`changed_when: false`, `check_mode: false`), dann `useradd -D -f 45` nur `when: "'INACTIVE=45' not in result.stdout_lines"`.

## Hinweis 3

```yaml
- name: CIS 5.4.1 - password aging and inactive accounts
  hosts: "..."
  become: "..."
  vars:
    cis_login_defs: {PASS_MAX_DAYS: "...", PASS_MIN_DAYS: "...", PASS_WARN_AGE: "..."}
    cis_strong_hash_methods: ["...", "..."]
  tasks:
    - name: Check whether /etc/login.defs exists
      ansible.builtin.stat:
        path: "..."
      register: cis_login_defs_file

    - name: Set password aging in /etc/login.defs
      ansible.builtin.lineinfile:
        path: /etc/login.defs
        regexp: "..."            # der Schlüssel am Anfang einer aktiven Zeile
        line: "..."
      loop: "{{ cis_login_defs | dict2items }}"
      when: "..."                # nur, wo die Datei existiert

    - name: Vendor-split systems - create the drop-in directory
      ansible.builtin.file: "..."            # /etc/login.defs.d, 0755 root:root

    - name: Vendor-split systems - set password aging in a drop-in
      ansible.builtin.lineinfile: "..."      # 50-cis.defs, create: true, gleiche Schleife

    - name: Read the current login.defs
      ansible.builtin.slurp:
        src: /etc/login.defs
      register: cis_login_defs_content
      when: "..."

    - name: Determine the current hashing method
      ansible.builtin.set_fact:
        cis_current_hash: "..."  # letzter ENCRYPT_METHOD-Wert, groß geschrieben, 'none' falls keiner

    - name: Use SHA512 only when nothing strong is configured
      ansible.builtin.lineinfile: "..."
      when: "..."                # Datei existiert und das Verfahren steht nicht in der starken Liste

    - name: Read useradd defaults
      ansible.builtin.command: useradd -D
      register: cis_useradd_defaults
      changed_when: "..."
      check_mode: "..."          # es liest nur: auch unter --check laufen lassen

    - name: Lock accounts after the inactivity period
      ansible.builtin.command: "..."
      when: "..."                # INACTIVE=45 noch nicht in der Ausgabe
      changed_when: true
```

`check_mode: false` an den *Lese*-Tasks hält `--check`-Läufe aussagekräftig. Vollständige Referenz: `lab solution 3.02`.
