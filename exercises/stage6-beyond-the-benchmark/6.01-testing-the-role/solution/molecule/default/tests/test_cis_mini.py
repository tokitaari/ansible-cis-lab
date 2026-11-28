"""Tests for the role cis_mini - the requirements of exercise 6.01, written down a second time.

The expected values come from the requirements table, not from the role: a test that reads the
role's own variables passes on every bug in them.
"""
import pytest

BANNER = "Authorized users only. All activity may be monitored and reported.\n"

# group and mode of /etc/shadow and /etc/gshadow per inventory group (owner: root everywhere)
SHADOW = {
    "debian_family": ("shadow", 0o640),
    "redhat_family": ("root", 0o000),
    "suse_family": ("shadow", 0o640),
    "arch_family": ("root", 0o600),
    "alpine_family": ("shadow", 0o640),
}


def family(host):
    """The one family group of the host in the lab inventory."""
    found = [g for g in host.ansible.get_variables()["group_names"] if g in SHADOW]
    assert len(found) == 1, f"expected one family group, found {found}"
    return found[0]


@pytest.mark.parametrize("path", ["/etc/passwd", "/etc/group"])
def test_account_file(host, path):
    f = host.file(path)
    assert (f.user, f.group, f.mode) == ("root", "root", 0o644)


@pytest.mark.parametrize("path", ["/etc/shadow", "/etc/gshadow"])
def test_shadow_file(host, path):
    f = host.file(path)
    if path == "/etc/gshadow" and not f.exists:
        pytest.skip("no /etc/gshadow on this host")
    group, mode = SHADOW[family(host)]
    assert (f.user, f.group, f.mode) == ("root", group, mode)


@pytest.mark.parametrize("path", ["/etc/issue", "/etc/issue.net"])
def test_banner(host, path):
    f = host.file(path)
    assert (f.user, f.group, f.mode) == ("root", "root", 0o644)
    assert f.content_string == BANNER
