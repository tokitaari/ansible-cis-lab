# 0.03 - Facts: ein Bericht über acht Distributionen

## Hinweis 1

Zwei Plays: Play 1 zielt auf `targets` und sammelt nur Facts (`tasks: []` reicht). Play 2 läuft auf `localhost` und rendert das Template.

## Hinweis 2

In Play 2 über `groups['targets']` iterieren und `hostvars[host]['ansible_facts']['os_family']` usw. lesen. Fact-Schlüssel: `distribution`, `distribution_version`, `os_family`, `pkg_mgr`, `service_mgr`, `python_version`.

## Hinweis 3

Die zwei Plays als Gerüst - fülle jedes `"..."` aus.

```yaml
- name: Gather facts from all targets
  hosts: "..."                      # die Hosts, von denen du Facts willst
  gather_facts: "..."
  tasks: []

- name: Write the platform report on the control node
  hosts: "..."                      # der Control-Node
  gather_facts: false
  tasks:
    - name: Ensure the work directory exists
      ansible.builtin.file:
        path: "..."                 # das Übungsverzeichnis unter dem Work-Verzeichnis
        state: directory
        mode: "0755"

    - name: Render facts.csv
      ansible.builtin.template:
        src: "..."                  # templates/facts.csv.j2
        dest: "..."                 # facts.csv in diesem Verzeichnis
        mode: "0644"
```

`templates/facts.csv.j2` ist die Kopfzeile gefolgt von dieser Schleife; jedes `...` ist ein Fact-Schlüssel, das zweite Argument von `get` ist der Platzhalter für einen Host ohne Facts:

```jinja
{% for h in groups['targets'] | sort %}
{% set f = hostvars[h]['ansible_facts'] | default({}) %}
{{ h }},{{ f.get('...', '-') }},{{ f.get('...', '-') }},{{ f.get('...', '-') }},{{ f.get('...', '-') }},{{ f.get('...', '-') }},{{ f.get('...', '-') }}
{% endfor %}
```

Referenz: `lab solution 0.03`.
