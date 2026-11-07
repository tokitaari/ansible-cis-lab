# 0.03 - Facts: one report across eight distributions

## Hint 1

Two plays: play 1 targets `targets` and just gathers facts (`tasks: []` is fine). Play 2 runs on `localhost` and renders the template.

## Hint 2

In play 2, iterate over `groups['targets']` and read `hostvars[host]['ansible_facts']['os_family']` etc. Fact keys: `distribution`, `distribution_version`, `os_family`, `pkg_mgr`, `service_mgr`, `python_version`.

## Hint 3

The two plays as a skeleton - fill in every `"..."`.

```yaml
- name: Gather facts from all targets
  hosts: "..."                      # the hosts you want facts from
  gather_facts: "..."
  tasks: []

- name: Write the platform report on the control node
  hosts: "..."                      # the control node
  gather_facts: false
  tasks:
    - name: Ensure the work directory exists
      ansible.builtin.file:
        path: "..."                 # the exercise directory below the work dir
        state: directory
        mode: "0755"

    - name: Render facts.csv
      ansible.builtin.template:
        src: "..."                  # templates/facts.csv.j2
        dest: "..."                 # facts.csv in that directory
        mode: "0644"
```

`templates/facts.csv.j2` is the header line followed by this loop; each `...` is one fact key, the second argument of `get` is the placeholder for a host without facts:

```jinja
{% for h in groups['targets'] | sort %}
{% set f = hostvars[h]['ansible_facts'] | default({}) %}
{{ h }},{{ f.get('...', '-') }},{{ f.get('...', '-') }},{{ f.get('...', '-') }},{{ f.get('...', '-') }},{{ f.get('...', '-') }},{{ f.get('...', '-') }}
{% endfor %}
```

Reference: `lab solution 0.03`.
