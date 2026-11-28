# 6.01 - Testing a role: Molecule scenario with testinfra

## Hint 1

Read the role first (`cat /lab/work/roles/cis_mini/*/main.yml`) and look at the targets (`ansible targets -m ansible.builtin.stat -a path=/etc/shadow`). A scenario needs three files: `molecule.yml`, `converge.yml` (a playbook that applies the role to `targets`) and a test file in `tests/`. `molecule init scenario` writes more than that, for a driver that creates instances - you do not need its `create.yml` and `destroy.yml`. Lesson L18 names the three things Molecule's own `ansible.cfg` takes away; put them back in `molecule.yml`. While you write the tests, run `molecule converge` once and then `molecule verify` as often as you like - it is much faster than `molecule test`.

## Hint 2

- Inventory: `ansible.executor.args.ansible_playbook` takes `--inventory=/lab/ansible/inventory/hosts.yml`. testinfra does not see that argument: give it the same path as `ansible-inventory` in `verifier.options`, else it stops with "No inventory was parsed".
- Role path: `ansible.env` sets environment variables for every Ansible run, and Molecule replaces `${MOLECULE_PROJECT_DIRECTORY}` in `molecule.yml`: `ANSIBLE_ROLES_PATH: ${MOLECULE_PROJECT_DIRECTORY}/../roles`.
- SSH: copy `ssh_args` (and `pipelining`) from `/lab/ansible/ansible.cfg` into `ansible.cfg.ssh_connection` of `molecule.yml`. Without them `molecule verify` on its own can stop at "Host key verification failed".
- The family of a host: the lab inventory groups the hosts by family, and `host.ansible.get_variables()["group_names"]` gives a test those groups. Write the expected values of R2 as a dict in the test file.
- `pytest.mark.parametrize` runs one test function per file; `oct(f.mode)` makes a failure readable (`416` is `0o640`).
- When `molecule test` fails, read the `CRITICAL` line and the lines that start with `*` or `FAILED`: the summary at the very end can call a failed idempotence step "Successful".

## Hint 3

The scenario as a skeleton - fill in every `"..."`. `converge.yml` is a normal play: `hosts: targets`, `become: true`, the role `cis_mini`.

```yaml
# molecule/default/molecule.yml
driver:
  name: default
  options:
    managed: "..."                    # the hosts exist: Molecule creates and destroys nothing
ansible:
  cfg:
    ssh_connection:
      pipelining: true
      ssh_args: "..."                 # the line from /lab/ansible/ansible.cfg
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
    - "..."                           # syntax, then the three steps of the requirements
```

```python
# molecule/default/tests/test_cis_mini.py
import pytest

BANNER = "..."                        # the text of cis_mini_banner and a newline
SHADOW = {"debian_family": ("shadow", 0o640)}  # ... one entry per family group


def family(host):
    ...                               # the one group of host.ansible.get_variables()["group_names"] in SHADOW


@pytest.mark.parametrize("path", ["/etc/passwd", "/etc/group"])
def test_account_file(host, path):
    f = host.file(path)
    assert ...                        # owner, group, mode


# test_shadow_file: skip /etc/gshadow where it does not exist (pytest.skip)
# test_banner: owner, group, mode and f.content_string
```

Then fix the role until `molecule test` passes. Reference: `lab solution 6.01`.
