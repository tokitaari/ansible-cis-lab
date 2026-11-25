# 4.09 - Systemprotokollierung: ein Logger je Host, gewählt über Daten

## Hinweis 1

Erst ansehen: `ansible 'targets:!alpine' -m ansible.builtin.command -a "systemd-analyze cat-config systemd/journald.conf"` listet jede Datei in der Reihenfolge, in der journald sie liest, und der letzte Wert eines Schlüssels gewinnt. Vergleiche debian mit rocky und suche auf beiden nach `/var/log/journal`. Die Wahl selbst ist eine Zeile: `cis_logger: "{{ cis_logger_by_family[ansible_facts.os_family] }}"`, geprüft von einem `ansible.builtin.assert` vor der ersten Änderung; jeder Block des Plays hat dann ein `when:` auf `cis_logger`.

## Hinweis 2

- debian und ubuntu liefern ein Drop-in in `/usr/lib/systemd/journald.conf.d/`, das `ForwardToSyslog=yes` setzt. Drop-ins werden über alle Verzeichnisse hinweg nach Dateinamen sortiert, also wird es nach `60-cis.conf` gelesen. Eine Datei mit gleichem Namen in `/etc/systemd/journald.conf.d/` ersetzt es; ein Symlink auf `/dev/null` entfernt es. Finde solche Dateien mit `ansible.builtin.find` und `contains:`, statt einen Namen fest einzutragen - und nur auf den Hosts mit nur journald.
- rocky und alma haben kein `/var/log/journal`. Nach einem Neustart mit `Storage=persistent` schreibt journald weiter nach `/run/log/journal`, bis `journalctl --flush` es zum Umzug auffordert. Zwei Handler, die mit `listen:` auf denselben Namen hören, laufen nacheinander, in der Reihenfolge des Abschnitts `handlers:`.
- `validate: rsyslogd -N1 -f %s` lehnt ein gültiges Drop-in ab (ein Drop-in hat keine Actions). Führe `rsyslogd -N1` (die ganze Konfiguration) als Task nach dem Drop-in aus: Ein fehlgeschlagener Task stoppt den Host, und seine ausstehenden Handler laufen nicht.
- Auf Alpine nimmt `ansible.builtin.service` mit `enabled: true` den Dienst in den Runlevel `default` auf.

## Hinweis 3

Die Tasks als Gerüst - fülle jedes `"..."` aus. Die Daten (`cis_logger_by_family`, `cis_logger`, die journald-Schlüssel als Dict, die syslogd-Optionen) gehören in `vars:`.

```yaml
- name: The logger of this host is a known one
  ansible.builtin.assert:
    that: "..."                       # cis_logger ist einer der drei Namen
    fail_msg: "..."

- name: Configure journald (every systemd host)
  when: "..."                         # journald oder rsyslog
  block:
    - name: Drop-in directory
      ansible.builtin.file:
        path: "..."
        state: directory
        mode: "0755"

    - name: CIS drop-in
      ansible.builtin.template:
        src: "..."                    # [Journal] + ein Key=value je Dict-Eintrag;
        dest: "..."                   # ForwardToSyslog=no nur für journald
        mode: "0644"
      notify: "..."                   # der Name, auf den beide journald-Handler hören

    - name: Vendor drop-in directory
      ansible.builtin.stat:
        path: "..."
      register: cis_vendor_dir

    - name: Vendor drop-ins that set ForwardToSyslog
      ansible.builtin.find:
        paths: "..."
        patterns: "*.conf"
        contains: "..."
      register: cis_vendor_forward
      when: "..."                     # nur, wenn das Verzeichnis existiert

    - name: Mask them on journald-only hosts
      ansible.builtin.file:
        src: "..."
        dest: "..."                   # gleicher Dateiname, unter /etc
        state: link
      loop: "..."                     # die gefundenen Dateien, [] wenn übersprungen
      when: "..."
      notify: "..."

- name: Configure rsyslog
  when: "..."
  block:
    - name: Package
      ansible.builtin.package:
        name: "..."
        state: present

    - name: CIS drop-in
      ansible.builtin.copy:
        dest: "..."
        content: "..."
        mode: "0644"
      notify: "..."

    - name: Whole configuration is valid
      ansible.builtin.command: "..."
      changed_when: "..."

    - name: Service
      ansible.builtin.service:
        name: "..."
        enabled: "..."
        state: "..."

- name: Configure busybox syslogd
  when: "..."
  block:
    - name: Rotation options
      ansible.builtin.lineinfile:
        path: "..."
        regexp: "..."
        line: "..."
      notify: "..."

    - name: Service in the default runlevel
      ansible.builtin.service:
        name: "..."
        enabled: "..."
        state: "..."
```

Die Handler: `ansible.builtin.systemd_service` startet `systemd-journald` neu und `ansible.builtin.command: journalctl --flush` (mit `changed_when: true`) zieht das Journal um, beide mit demselben `listen:`; je ein `ansible.builtin.service`-Handler startet `rsyslog` und `syslog` neu. Referenz: `lab solution 4.09`.
