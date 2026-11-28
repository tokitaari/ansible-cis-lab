# 6.01 - Eine Rolle testen: Molecule-Szenario mit testinfra

## Hinweis 1

Lies zuerst die Rolle (`cat /lab/work/roles/cis_mini/*/main.yml`) und sieh dir die Targets an (`ansible targets -m ansible.builtin.stat -a path=/etc/shadow`). Ein Szenario braucht drei Dateien: `molecule.yml`, `converge.yml` (ein Playbook, das die Rolle auf `targets` anwendet) und eine Testdatei in `tests/`. `molecule init scenario` schreibt mehr, für einen Driver, der Instanzen anlegt - seine `create.yml` und `destroy.yml` brauchst du nicht. Lektion L18 nennt die drei Dinge, die Molecules eigene `ansible.cfg` wegnimmt; setze sie in `molecule.yml` wieder ein. Während du die Tests schreibst, führe einmal `molecule converge` aus und dann `molecule verify`, so oft du willst - das ist viel schneller als `molecule test`.

## Hinweis 2

- Inventar: `ansible.executor.args.ansible_playbook` nimmt `--inventory=/lab/ansible/inventory/hosts.yml`. testinfra sieht dieses Argument nicht: Gib ihm denselben Pfad als `ansible-inventory` in `verifier.options`, sonst bricht es mit "No inventory was parsed" ab.
- Rollenpfad: `ansible.env` setzt Umgebungsvariablen für jeden Ansible-Lauf, und Molecule ersetzt `${MOLECULE_PROJECT_DIRECTORY}` in `molecule.yml`: `ANSIBLE_ROLES_PATH: ${MOLECULE_PROJECT_DIRECTORY}/../roles`.
- SSH: Übernimm `ssh_args` (und `pipelining`) aus `/lab/ansible/ansible.cfg` in `ansible.cfg.ssh_connection` von `molecule.yml`. Ohne sie kann `molecule verify` allein an "Host key verification failed" scheitern.
- Die Familie eines Hosts: Das Lab-Inventar gruppiert die Hosts nach Familie, und `host.ansible.get_variables()["group_names"]` gibt einem Test diese Gruppen. Schreibe die Sollwerte von R2 als Dict in die Testdatei.
- `pytest.mark.parametrize` führt eine Testfunktion je Datei aus; `oct(f.mode)` macht einen Fehler lesbar (`416` ist `0o640`).
- Scheitert `molecule test`, lies die `CRITICAL`-Zeile und die Zeilen, die mit `*` oder `FAILED` beginnen: Die Zusammenfassung ganz am Ende kann einen gescheiterten Idempotenz-Schritt "Successful" nennen.

## Hinweis 3

Das Szenario als Gerüst - fülle jedes `"..."`. `converge.yml` ist ein normales Play: `hosts: targets`, `become: true`, die Rolle `cis_mini`.

```yaml
# molecule/default/molecule.yml
driver:
  name: default
  options:
    managed: "..."                    # die Hosts gibt es: Molecule legt nichts an und löscht nichts
ansible:
  cfg:
    ssh_connection:
      pipelining: true
      ssh_args: "..."                 # die Zeile aus /lab/ansible/ansible.cfg
  env:
    ANSIBLE_ROLES_PATH: "..."         # ${MOLECULE_PROJECT_DIRECTORY}/...
  executor:
    args:
      ansible_playbook:
        - "..."                       # --inventory=...
verifier:
  name: "..."
  options:
    ansible-inventory: "..."
    hosts: "..."
scenario:
  test_sequence:
    - "..."                           # syntax, dann die drei Schritte aus den Anforderungen
```

```python
# molecule/default/tests/test_cis_mini.py
import pytest

BANNER = "..."                        # der Text von cis_mini_banner und ein Zeilenumbruch
SHADOW = {"debian_family": ("shadow", 0o640)}  # ... ein Eintrag je Familiengruppe


def family(host):
    ...                               # die eine Gruppe aus host.ansible.get_variables()["group_names"], die in SHADOW steht


@pytest.mark.parametrize("path", ["/etc/passwd", "/etc/group"])
def test_account_file(host, path):
    f = host.file(path)
    assert ...                        # Eigentümer, Gruppe, Modus


# test_shadow_file: /etc/gshadow überspringen, wo es fehlt (pytest.skip)
# test_banner: Eigentümer, Gruppe, Modus und f.content_string
```

Dann korrigiere die Rolle, bis `molecule test` besteht. Musterlösung: `lab solution 6.01`.
