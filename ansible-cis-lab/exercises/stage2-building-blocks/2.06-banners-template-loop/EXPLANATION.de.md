# 2.06 - Alle Login-Banner aus einem Template: Erklärung

### Lösung
```yaml
- name: CIS 1.6 - warning banners
  hosts: targets
  become: true
  tasks:
    - name: Deploy login banners
      ansible.builtin.template:
        src: banner.j2
        dest: "{{ item }}"
        owner: root
        group: root
        mode: "0644"
      loop: [/etc/motd, /etc/issue, /etc/issue.net]
```
`templates/banner.j2`:
```
{{ lab_org_name }} - authorized access only.
Activity on this system is monitored and logged. Disconnect now if you are not an authorized user.
```

### Woher Variablen kommen
`lab_org_name` steht in `/lab/ansible/inventory/group_vars/all.yml`. Variablenvorrang
(niedrig → hoch, vereinfacht): Rollen-Defaults → Inventar-group_vars (all → Kindgruppen)
→ host_vars → Play-Vars → `-e`-Extra-Vars. `ansible-inventory --host alpine` zeigt das
Ergebnis.

### Hier kein `ansible_managed`
In Konfigurationsdateien ist der Kommentar hilfreich; in einem Banner würde jeder
Benutzer "Ansible managed" lesen. Bewusst entscheiden.

### Dynamische MOTD (Bonus)
Ubuntu baut die Login-Nachricht aus Skripten in `/etc/update-motd.d/` - manche geben
Kernel- und Distributionsversion aus. CIS interessiert, was der Benutzer *sieht*;
deaktiviere diese Skripte (Ausführungsbit entfernen) oder den dynamischen Teil von
`pam_motd`.

## Musterlösung

Anzeigen mit `lab solution 2.06`, anwenden mit `lab solve 2.06`.
