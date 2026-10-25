# 2.01 - /etc/shadow: richtige Rechte je OS-Familie: Erklärung

### Lösung
```yaml
- name: Protect password hashes
  hosts: targets
  become: true
  vars:
    shadow_perms:
      Debian:    {group: shadow, mode: "0640"}
      Suse:      {group: shadow, mode: "0640"}
      Alpine:    {group: shadow, mode: "0640"}
      RedHat:    {group: root,   mode: "0000"}
      Archlinux: {group: root,   mode: "0600"}
    shadow_paths: [/etc/shadow, /etc/gshadow, /etc/shadow-, /etc/gshadow-]
  tasks:
    - name: Find which shadow files exist
      ansible.builtin.stat:
        path: "{{ item }}"
      loop: "{{ shadow_paths }}"
      register: shadow_files
    - name: Set owner, group and mode
      ansible.builtin.file:
        path: "{{ item.item }}"
        owner: root
        group: "{{ shadow_perms[ansible_facts.os_family].group }}"
        mode: "{{ shadow_perms[ansible_facts.os_family].mode }}"
      loop: "{{ shadow_files.results }}"
      loop_control:
        label: "{{ item.item }}"
      when: item.stat.exists
```

### Daten statt Bedingungen
Fünf Tasks mit `when: os_family == 'X'` würden funktionieren, aber jede neue
Distribution heißt, jeden Task anzufassen. Eine Nachschlagetabelle trennt *Daten*
(was sich unterscheidet) von *Logik* (was zu tun ist). Das ist die Grundidee hinter
`vars/<os_family>.yml` in Rollen (Stufe 3/4).

### register + loop
Ein `stat` in einer Schleife registriert `shadow_files.results` - ein Eintrag pro
Element, jeweils mit `item` (Eingabe) und `stat`. `loop_control.label` hält die Ausgabe
lesbar.

### Modus 0000?
Root ignoriert Rechte-Bits beim Lesen (CAP_DAC_OVERRIDE). `0000` kostet root also nichts
und sperrt alle anderen aus. RHEL nutzt es als strengstmöglichen Wert.

### Stolperfalle
Eine unbekannte Familie (z. B. eine neue Distribution) erzeugt "dict object has no
attribute ...". Produktionscode ergänzt einen Default:
`shadow_perms[ansible_facts.os_family] | default({'group': 'root', 'mode': '0600'})`.

## Musterlösung

Anzeigen mit `lab solution 2.01`, anwenden mit `lab solve 2.01`.
