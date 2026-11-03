#!/usr/bin/env python3
"""Container-free consistency checks for the lab repository.

Called by tools/static-check.sh (which also runs yamllint and ansible-lint):
    python3 tools/static_check.py [meta] [parity] [links] [controls] [lessons]
Without arguments all checks run. Exit code 1 if any check reports a failure.

  meta      meta.yml schema (incl. requires: earlier, known ids), exercise layout,
            solve/hosts vs. solution and check,
            README header table and INDEX rows vs. meta.yml
  parity    every EN Markdown file has a DE twin (*.de.md) with the same structure;
            bash/yaml/... code blocks hold the same code (comments may be translated)
  links     relative Markdown links (and #anchors) resolve
  controls  cis/controls.yml schema and cross-references to the exercises
  lessons   docs/lessons/LNN-slug(.de).md: title, language switch, header table (exercises,
            CIS ids, reading time, earlier lessons - all known, sorted), the eight fixed
            sections, self-check questions with one folded answer each; EN/DE header values
            equal. TEMPLATE(.de).md: structure only
"""
import collections
import os
import re
import subprocess
import sys
import unicodedata

import yaml

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), os.pardir))
EX_ROOT = os.path.join(ROOT, "exercises")

# EN Markdown files that intentionally have no DE twin.
PARITY_EXEMPT = {
    "CHANGELOG.md": "release notes are English only",
    # P0 audit gap G8 - remove the entries once the translations exist
    "ansible/roles/README.md": "G8",
    "exercises/stage5-capstone/5.02-rollout-strategy/solution/roles/README.md": "G8",
    "exercises/stage5-capstone/5.03-compare-with-community-role/solution/NOTES.md": "G8",
}

failures = collections.Counter()


quiet = set()  # checks that run only as a prerequisite of another one


def fail(check, msg):
    failures[check] += 1
    if check not in quiet:
        print(f"FAIL [{check}] {msg}")


def rel(path):
    return os.path.relpath(path, ROOT)


def tracked_files():
    """Files tracked by git; falls back to a directory walk (e.g. no git in the container)."""
    try:
        out = subprocess.run(["git", "-C", ROOT, "ls-files", "-z"], capture_output=True,
                             check=True).stdout.decode()
        files = [f for f in out.split("\0") if f]
        if files:
            return sorted(f for f in files if os.path.exists(os.path.join(ROOT, f)))
    except (OSError, subprocess.CalledProcessError):
        pass
    skip = {".git", "work", ".lab", ".ansible", "__pycache__", "pdf"}
    files = []
    for dirpath, dirnames, filenames in os.walk(ROOT):
        dirnames[:] = [d for d in dirnames if d not in skip]
        files += [rel(os.path.join(dirpath, f)) for f in filenames]
    return sorted(files)


def load_yaml(path):
    with open(path, encoding="utf-8") as fh:
        return yaml.safe_load(fh)


def read(path):
    with open(path, encoding="utf-8") as fh:
        return fh.read()


# --------------------------------------------------------------------------- exercises

EX_DIR_RE = re.compile(r"^stage(\d)-[a-z0-9-]+/(\d\.\d\d)-([a-z0-9]+(?:-[a-z0-9]+)*)$")
ID_RE = re.compile(r"^\d\.\d\d$")  # exercise id, e.g. 3.01 (also the format id_key() parses)


def exercises():
    """[(dir, meta)] for every exercise directory, sorted by id."""
    out = []
    for stage in sorted(os.listdir(EX_ROOT)):
        sdir = os.path.join(EX_ROOT, stage)
        if not (stage.startswith("stage") and os.path.isdir(sdir)):
            continue
        for name in sorted(os.listdir(sdir)):
            d = os.path.join(sdir, name)
            if not os.path.isdir(d):
                continue
            mfile = os.path.join(d, "meta.yml")
            if not os.path.isfile(mfile):
                fail("meta", f"{rel(d)}: meta.yml missing")
                continue
            try:
                m = load_yaml(mfile)
            except yaml.YAMLError as exc:
                fail("meta", f"{rel(mfile)}: invalid YAML: {exc}")
                continue
            out.append((d, m if isinstance(m, dict) else {}))
    return out


# --------------------------------------------------------------------------- meta

META_KEYS = ["id", "slug", "stage", "stage_name", "stage_name_de", "title", "difficulty",
             "minutes", "cis", "hosts", "requires", "concepts", "idempotency", "solve"]
EX_FILES = ["README.md", "README.de.md", "HINTS.md", "HINTS.de.md",
            "EXPLANATION.md", "EXPLANATION.de.md"]
HINT_HEADINGS = {"HINTS.md": "Hint", "HINTS.de.md": "Hinweis"}


def is_str(v):
    return isinstance(v, str) and v.strip() != ""


def stars(n):
    return "★" * n + "☆" * (5 - n)


def plays(path):
    try:
        data = load_yaml(path)
    except (OSError, yaml.YAMLError):
        return []
    return [p for p in data or [] if isinstance(p, dict) and "hosts" in p]


def table_rows(text):
    """Data rows of all Markdown tables: list of cell lists."""
    rows = []
    for line in text.splitlines():
        s = line.strip()
        if s.startswith("|") and s.endswith("|") and not re.fullmatch(r"\|[\s:|-]+\|", s):
            rows.append([c.strip() for c in s[1:-1].split("|")])
    return rows


def check_meta():
    exs = exercises()
    seen = {}
    stage_names = {}
    requires = {}
    for d, m in exs:
        r = rel(d)
        keys = list(m)
        if keys != META_KEYS:
            missing = [k for k in META_KEYS if k not in m]
            extra = [k for k in keys if k not in META_KEYS]
            if missing or extra:
                fail("meta", f"{r}/meta.yml: missing keys {missing}, unknown keys {extra}")
                continue
            fail("meta", f"{r}/meta.yml: key order differs from {META_KEYS}")
        mid = m["id"]
        match = EX_DIR_RE.match(os.path.relpath(d, EX_ROOT))
        if not isinstance(mid, str) or not match:
            fail("meta", f"{r}: directory must be stage<N>-<name>/<N.NN>-<slug>, id a quoted string")
            continue
        if not ID_RE.match(mid):
            # report and skip: everything below (stage prefix, requires order) parses the id
            fail("meta", f"{r}: id {mid!r} must look like '<stage>.<NN>', e.g. '3.01'")
            continue
        if (match.group(2), match.group(3)) != (mid, m["slug"]):
            fail("meta", f"{r}: directory name != '<id>-<slug>' ({mid}-{m['slug']})")
        if not (m["stage"] == int(match.group(1)) == int(mid[0])):
            fail("meta", f"{r}: stage {m['stage']!r} != stage directory / id prefix")
        if mid in seen:
            fail("meta", f"{r}: id {mid} also used by {seen[mid]}")
        seen[mid] = r
        names = (m["stage_name"], m["stage_name_de"])
        if not all(is_str(n) for n in names):
            fail("meta", f"{r}: stage_name / stage_name_de must be non-empty strings")
        elif stage_names.setdefault(m["stage"], names) != names:
            fail("meta", f"{r}: stage names {names} differ from {stage_names[m['stage']]}")
        t = m["title"]
        if not (isinstance(t, dict) and set(t) == {"en", "de"} and all(is_str(v) for v in t.values())):
            fail("meta", f"{r}: title must have exactly the non-empty keys en, de")
        if not (type(m["difficulty"]) is int and 1 <= m["difficulty"] <= 5):
            fail("meta", f"{r}: difficulty must be an integer 1-5")
        if not (type(m["minutes"]) is int and m["minutes"] > 0):
            fail("meta", f"{r}: minutes must be a positive integer")
        c = m["cis"]
        if not (isinstance(c, dict) and set(c) == {"section", "level"} and all(is_str(v) for v in c.values())):
            fail("meta", f"{r}: cis must have exactly the string keys section, level")
        if not is_str(m["hosts"]):
            fail("meta", f"{r}: hosts must be a non-empty string")
        rq = m["requires"]
        if not (isinstance(rq, list) and all(is_str(x) for x in rq)):
            fail("meta", f"{r}: requires must be a list of exercise ids (strings), [] for none")
        else:
            requires[r] = (mid, rq)
        cc = m["concepts"]
        if not (isinstance(cc, list) and cc and all(is_str(x) for x in cc)):
            fail("meta", f"{r}: concepts must be a non-empty list of strings")
        if type(m["idempotency"]) is not bool:
            fail("meta", f"{r}: idempotency must be true or false")
        if not is_str(m["solve"]):
            fail("meta", f"{r}: solve must be a non-empty string")
            continue
        check_layout(d, m)
    check_requires(requires, seen)
    check_readme_headers(exs)
    check_index(exs)
    return exs


def id_key(i):
    return tuple(int(x) for x in i.split("."))


def check_requires(requires, seen):
    """requires = direct technical prerequisites (target state, files in work/), not the
    didactic order: known ids, earlier than the exercise itself (no cycles), sorted, unique."""
    for r, (mid, rq) in requires.items():
        unknown = [x for x in rq if x not in seen]
        if unknown:
            fail("meta", f"{r}: requires unknown exercise ids {unknown}")
            continue
        later = [x for x in rq if id_key(x) >= id_key(mid)]
        if later:
            fail("meta", f"{r}: requires {later} - only earlier exercises can be prerequisites")
        if rq != sorted(set(rq), key=id_key):
            fail("meta", f"{r}: requires must be sorted and free of duplicates")


def check_layout(d, m):
    r = rel(d)
    for f in EX_FILES:
        if not os.path.isfile(os.path.join(d, f)):
            fail("meta", f"{r}: {f} missing")
    checks = [f for f in ("check.yml", "check.sh") if os.path.isfile(os.path.join(d, f))]
    if len(checks) != 1:
        fail("meta", f"{r}: needs exactly one of check.yml / check.sh (found {checks or 'none'})")
    sol = os.path.join(d, "solution")
    if not os.path.isdir(sol):
        fail("meta", f"{r}: solution/ missing")
    for f, word in HINT_HEADINGS.items():
        p = os.path.join(d, f)
        if os.path.isfile(p):
            got = re.findall(r"^## (.+?)\s*$", read(p), re.M)
            want = [f"{word} {i}" for i in (1, 2, 3)]
            if got != want:
                fail("meta", f"{r}/{f}: headings {got} != {want}")
    # solve: the referenced file exists in solution/; the play runs on meta.hosts
    tokens = m["solve"].split()
    target = None
    if tokens[0] == "ansible-playbook":
        target = next((t for t in tokens[1:] if t.endswith((".yml", ".yaml"))), None)
        if not target:
            fail("meta", f"{r}: solve runs ansible-playbook without a playbook file")
    elif tokens[0] == "bash" and len(tokens) > 1:
        target = tokens[1]
    if target and not os.path.isfile(os.path.join(sol, target)):
        fail("meta", f"{r}: solve references solution/{target}, which does not exist")
    elif target and target.endswith((".yml", ".yaml")):
        # meta.hosts is a play's hosts, or the --limit of the solve command (4.02: -l debian)
        hosts = [p["hosts"] for p in plays(os.path.join(sol, target))]
        limit = [b for a, b in zip(tokens, tokens[1:]) if a in ("-l", "--limit")]
        if m["hosts"] not in hosts + limit:
            fail("meta", f"{r}: hosts '{m['hosts']}' is neither a play in solution/{target} "
                         f"({hosts}) nor the --limit of solve")


def check_readme_headers(exs):
    for d, m in exs:
        if list(m) != META_KEYS:
            continue
        for f, lang, title, stage, minutes in (
                ("README.md", "en", m["title"].get("en"), m["stage_name"], f"~{m['minutes']} min"),
                ("README.de.md", "de", m["title"].get("de"), m["stage_name_de"], f"~{m['minutes']} Min.")):
            p = os.path.join(d, f)
            if not os.path.isfile(p):
                continue
            text = read(p)
            first = text.splitlines()[0] if text else ""
            if first != f"# {m['id']} - {title}":
                fail("meta", f"{rel(p)}: first line must be '# {m['id']} - {title}'")
            rows = table_rows(text)
            want = [stage, stars(m["difficulty"]), minutes,
                    f"{m['cis']['section']} ({m['cis']['level']})", f"`{m['hosts']}`"]
            if len(rows) < 2 or rows[1] != want:
                got = rows[1] if len(rows) > 1 else None
                fail("meta", f"{rel(p)}: header table {got} != meta.yml {want} ({lang})")


def check_index(exs):
    for f, lang, suffix in (("INDEX.md", "en", ".md"), ("INDEX.de.md", "de", ".de.md")):
        p = os.path.join(EX_ROOT, f)
        if not os.path.isfile(p):
            fail("meta", f"exercises/{f} missing")
            continue
        rows = {}
        for row in table_rows(read(p)):
            if re.fullmatch(r"\d\.\d\d", row[0]):
                if row[0] in rows:
                    fail("meta", f"exercises/{f}: {row[0]} listed twice")
                rows[row[0]] = row
        for d, m in exs:
            if list(m) != META_KEYS:  # already reported; do not report its row as orphaned
                rows.pop(m.get("id"), None)
                continue
            row = rows.pop(m["id"], None)
            link = os.path.relpath(os.path.join(d, "README" + suffix), EX_ROOT)
            want = [m["id"], f"[{m['title'].get(lang)}]({link})", stars(m["difficulty"]),
                    f"~{m['minutes']} min", m["cis"]["section"], f"`{m['hosts']}`"]
            if row != want:
                fail("meta", f"exercises/{f}: row {row} != meta.yml {want}")
        for extra in rows:
            fail("meta", f"exercises/{f}: row {extra} has no exercise directory")


# --------------------------------------------------------------------------- markdown

FENCE_RE = re.compile(r"^\s*(```+|~~~+)\s*([^\s`]*)")
INLINE_LINK_RE = re.compile(r"!?\[(?:[^\]\[]|\[[^\]]*\])*\]\(\s*<?([^)\s>]+)>?(?:\s+\"[^\"]*\")?\s*\)")
REF_DEF_RE = re.compile(r"^\s{0,3}\[[^\]]+\]:\s+<?(\S+?)>?(?:\s+.*)?$")
LIST_RE = re.compile(r"^\s*(?:[-*+]|\d+[.)])\s+")


PARITY_MARKER = "<!-- parity: lang-specific -->"


def md_scan(text):
    """Split Markdown into (prose lines, code blocks [(info, lines, marked)]).

    marked: the last non-blank line before the fence is PARITY_MARKER.
    """
    prose, blocks, fence, info, body, marked, last = [], [], None, "", [], False, ""
    for line in text.splitlines():
        m = FENCE_RE.match(line)
        if fence is None and m:
            fence, info, body = m.group(1)[0] * len(m.group(1)), m.group(2), []
            marked = last == PARITY_MARKER
        elif fence is not None and line.strip().startswith(fence) and line.strip().strip(fence[0]) == "":
            blocks.append((info, body, marked))
            fence, last = None, ""
        elif fence is not None:
            body.append(line)
        else:
            prose.append(line)
            if line.strip():
                last = line.strip()
    if fence is not None:
        blocks.append((info + " (unclosed)", body, marked))
    return prose, blocks


def code_without_comments(lines):
    """Code lines without '#' comments (full-line or after whitespace) and blank lines."""
    out = []
    for line in lines:
        line = re.sub(r"(^|\s)#.*$", "", line).rstrip()
        if line:
            out.append(line)
    return out


def strip_code_spans(line):
    return re.sub(r"(`+).*?\1", "", line)


def md_links(text):
    prose, _ = md_scan(text)
    links = []
    for line in prose:
        line = strip_code_spans(line)
        m = REF_DEF_RE.match(line)
        if m:
            links.append(m.group(1))
        links += INLINE_LINK_RE.findall(line)
    return links


def md_structure(text):
    prose, blocks = md_scan(text)
    headings, lists, rows = [], 0, 0
    for line in prose:
        m = re.match(r"^(#{1,6})\s", line)
        if m:
            headings.append(len(m.group(1)))
        elif LIST_RE.match(line):
            lists += 1
        elif line.strip().startswith("|"):
            rows += 1
    links = sorted(re.sub(r"\.de\.md(?=$|#)", ".md", t) for t in md_links(text))
    return {
        "heading levels": headings,
        "list items": lists,
        "table lines": rows,
        "code blocks (info strings)": [i for i, _, _ in blocks],
        "link targets (.de.md -> .md)": links,
    }


def check_parity(files):
    md = [f for f in files if f.endswith(".md")]
    have = set(md)
    for f in md:
        if f.endswith(".de.md"):
            if f[:-6] + ".md" not in have:
                fail("parity", f"{f}: no EN original {f[:-6]}.md")
            continue
        de = f[:-3] + ".de.md"
        if de not in have:
            if f not in PARITY_EXEMPT:
                fail("parity", f"{f}: no DE version {de}")
            continue
        if f in PARITY_EXEMPT:
            fail("parity", f"{f}: listed in PARITY_EXEMPT but {de} exists - remove the entry")
        en_t, de_t = read(os.path.join(ROOT, f)), read(os.path.join(ROOT, de))
        en_s, de_s = md_structure(en_t), md_structure(de_t)
        for key in en_s:
            if en_s[key] != de_s[key]:
                fail("parity", f"{f} vs {de}: {key} differ: {short(en_s[key])} vs {short(de_s[key])}")
        if en_s["code blocks (info strings)"] == de_s["code blocks (info strings)"]:
            check_code_parity(f, de, md_scan(en_t)[1], md_scan(de_t)[1])
    for f in PARITY_EXEMPT:
        if f not in have:
            fail("parity", f"PARITY_EXEMPT lists {f}, which does not exist - remove the entry")


def check_code_parity(en, de, en_blocks, de_blocks):
    """Code blocks with an info string (bash, yaml, ...) must hold the same code in EN and DE;
    comments may be translated. Blocks without an info string (diagrams, trees, placeholders)
    are translated freely. A deliberate difference needs PARITY_MARKER on the line before the
    block (in either file)."""
    for n, ((info, a, ma), (_, b, mb)) in enumerate(zip(en_blocks, de_blocks), 1):
        if not info or ma or mb:
            continue
        ca, cb = code_without_comments(a), code_without_comments(b)
        if ca != cb:
            diff = next((i for i, (x, y) in enumerate(zip(ca, cb)) if x != y), min(len(ca), len(cb)))
            got = (ca[diff] if diff < len(ca) else "<end>", cb[diff] if diff < len(cb) else "<end>")
            fail("parity", f"{en} vs {de}: code block {n} ({info}) differs outside comments: "
                           f"{got[0]!r} vs {got[1]!r} - fix the code or mark the DE block with "
                           f"{PARITY_MARKER}")


def short(v):
    if isinstance(v, list) and len(v) > 12:
        return f"[{len(v)} items] {v[:12]}..."
    return v


def gh_slug(heading):
    """GitHub-style anchor for a heading."""
    s = re.sub(r"[*_`]|\[([^\]]*)\]\([^)]*\)", r"\1", heading.strip()).lower()
    s = "".join(ch for ch in s if ch in " -_" or unicodedata.category(ch)[0] in "LN")
    return s.replace(" ", "-")


def anchors(path, cache={}):
    if path not in cache:
        seen = collections.Counter()
        out = set()
        prose, _ = md_scan(read(path))
        for line in prose:
            m = re.match(r"^#{1,6}\s+(.*?)\s*#*\s*$", line)
            if m:
                slug = gh_slug(m.group(1))
                out.add(slug if not seen[slug] else f"{slug}-{seen[slug]}")
                seen[slug] += 1
        cache[path] = out
    return cache[path]


def check_links(files):
    for f in (f for f in files if f.endswith(".md")):
        src = os.path.join(ROOT, f)
        for target in md_links(read(src)):
            if re.match(r"^[a-z][a-z0-9+.-]*:", target, re.I):
                continue  # http(s), mailto, ...
            path, _, frag = target.partition("#")
            path = path.split("?")[0]
            if path.startswith("/"):
                fail("links", f"{f}: absolute link '{target}' - use a path relative to the file")
                continue
            dest = os.path.normpath(os.path.join(os.path.dirname(src), path)) if path else src
            if not os.path.exists(dest):
                fail("links", f"{f}: broken link '{target}'")
            elif frag and dest.endswith(".md") and frag not in anchors(dest):
                fail("links", f"{f}: anchor '#{frag}' not found in {rel(dest)}")


# --------------------------------------------------------------------------- controls

CONTROL_KEYS = ["id", "section", "title", "level", "container", "exercises", "platforms"]
CIS_ID_RE = re.compile(r"^\d+(?:\.\d+)*$")


def check_controls(exs):
    path = os.path.join(ROOT, "cis", "controls.yml")
    try:
        data = load_yaml(path)
    except (OSError, yaml.YAMLError) as exc:
        fail("controls", f"cis/controls.yml: {exc}")
        return
    if not (isinstance(data, dict) and list(data) == ["controls"] and isinstance(data["controls"], list)):
        fail("controls", "cis/controls.yml: top level must be exactly 'controls: [...]'")
        return
    meta = {m["id"]: m for _, m in exs if list(m) == META_KEYS}
    known = {m.get("id") for _, m in exs}  # includes exercises whose meta.yml is invalid
    controls = {}
    for c in data["controls"]:
        cid = c.get("id") if isinstance(c, dict) else None
        where = f"cis/controls.yml: control {cid!r}"
        if not isinstance(c, dict) or list(c) != CONTROL_KEYS:
            fail("controls", f"{where}: keys must be {CONTROL_KEYS}")
            continue
        if not (isinstance(cid, str) and CIS_ID_RE.match(cid)):
            fail("controls", f"{where}: id must be a quoted dotted number")
            continue
        if cid in controls:
            fail("controls", f"{where}: duplicate id")
        controls[cid] = c
        if c["level"] not in (1, 2):
            fail("controls", f"{where}: level must be 1 or 2")
        if c["container"] not in ("full", "config", "no"):
            fail("controls", f"{where}: container must be full, config or \"no\"")
        if not all(is_str(c[k]) for k in ("section", "title", "platforms")):
            fail("controls", f"{where}: section, title, platforms must be non-empty strings")
        ex = c["exercises"]
        if not (isinstance(ex, list) and all(isinstance(x, str) for x in ex)):
            fail("controls", f"{where}: exercises must be a list of quoted ids")
            continue
        if ex != sorted(set(ex)):
            fail("controls", f"{where}: exercises must be sorted and unique")
        for x in ex:
            if x not in known:
                fail("controls", f"{where}: exercise {x} does not exist")
    ids = list(controls)
    if ids != sorted(ids, key=lambda i: [int(p) for p in i.split(".")]):
        fail("controls", "cis/controls.yml: controls are not sorted by id")
    # Every CIS id named in an exercise's meta cis.section must be a control that lists the
    # exercise, and the exercise level must cover the control level. Free text like
    # "Sections 1-7" or "(operations)" is not an id and is skipped; deeper ids than the
    # catalogue (e.g. 5.3.3.1) are reported only if they are not catalogue entries either.
    for mid, m in sorted(meta.items()):
        for part in m["cis"]["section"].split("/"):
            tok = part.split()[0] if part.split() else ""
            if not CIS_ID_RE.match(tok):
                continue
            c = controls.get(tok)
            if c is None:
                if not any(tok.startswith(k + ".") for k in controls):
                    fail("controls", f"exercise {mid}: CIS id {tok} (meta cis.section) is not in cis/controls.yml")
                continue
            if mid not in c["exercises"]:
                fail("controls", f"exercise {mid}: names CIS {tok} in meta.yml, but control {tok} "
                                 f"does not list it in exercises")
            if f"L{c['level']}" not in m["cis"]["level"]:
                fail("controls", f"exercise {mid}: level '{m['cis']['level']}' does not include "
                                 f"L{c['level']} of control {tok}")


# --------------------------------------------------------------------------- lessons

LESSON_DIR = "docs/lessons"
LESSON_NAME_RE = re.compile(r"^L(\d\d)-[a-z0-9]+(?:-[a-z0-9]+)*$")
LESSON_TEMPLATE = "TEMPLATE"
LESSON_SECTIONS = {
    "en": ["Learning goals", "Theory", "CIS background", "Platform differences", "Pitfalls",
           "Exercises", "Self-check", "Further reading"],
    "de": ["Lernziele", "Theorie", "CIS-Hintergrund", "Plattformunterschiede", "Stolperfallen",
           "Übungen", "Selbstkontrolle", "Weiterführendes"],
}
LESSON_HEAD = {"en": ["Exercises", "CIS sections", "Reading time", "Builds on"],
               "de": ["Übungen", "CIS-Abschnitte", "Lesezeit", "Baut auf"]}
LESSON_TIME_RE = {"en": re.compile(r"^~([1-9]\d*) min$"), "de": re.compile(r"^~([1-9]\d*) Min\.$")}
LESSON_SWITCH = {"en": "*[Deutsch]({}.de.md)*", "de": "*[English]({}.md)*"}
LESSON_ANSWER = {"en": "Answer", "de": "Antwort"}
LESSON_ID_RE = re.compile(r"^L\d\d$")


def control_ids():
    try:
        data = load_yaml(os.path.join(ROOT, "cis", "controls.yml"))
        return {c["id"] for c in data["controls"] if isinstance(c, dict) and "id" in c}
    except (OSError, yaml.YAMLError, KeyError, TypeError):
        return set()  # reported by the controls check


def lesson_list(where, label, cell, pattern, known, key):
    """'-' or a comma-separated, sorted, unique list of known ids -> list (None on error)."""
    if cell == "-":
        return []
    items = [x.strip() for x in cell.split(",")]
    bad = [x for x in items if not pattern.match(x)]
    if bad:
        fail("lessons", f"{where}: {label}: malformed {bad} - use '-' or e.g. "
                        f"{'3.01, 3.02' if pattern is ID_RE else '5.1, 5.2' if pattern is CIS_ID_RE else 'L00, L01'}")
        return None
    if items != sorted(set(items), key=key):
        fail("lessons", f"{where}: {label}: must be sorted and unique: {cell}")
    unknown = [x for x in items if x not in known]
    if unknown:
        fail("lessons", f"{where}: {label}: unknown {unknown}")
    return items


def lesson_sections(prose):
    """{H2 title: [prose lines]} plus the ordered list of H2 titles."""
    order, body, cur = [], {}, None
    for line in prose:
        m = re.match(r"^##\s+(.*?)\s*#*\s*$", line)
        if m and not line.startswith("###"):
            cur = m.group(1)
            order.append(cur)
            body[cur] = []
        elif cur is not None:
            body[cur].append(line)
    return order, body


def check_lesson(f, exs_known, controls, lessons):
    """One lesson file; returns its header cells (or None) for the EN/DE comparison."""
    lang = "de" if f.endswith(".de.md") else "en"
    stem = os.path.basename(f)[:-6 if lang == "de" else -3]
    template = stem == LESSON_TEMPLATE
    m = LESSON_NAME_RE.match(stem)
    if not (template or m):
        fail("lessons", f"{f}: file name must be LNN-slug.md / LNN-slug.de.md (or {LESSON_TEMPLATE}.md)")
        return None
    num = "NN" if template else m.group(1)
    prose, _ = md_scan(read(os.path.join(ROOT, f)))
    lines = [l for l in prose if l.strip()]
    if not lines or not re.match(rf"^# L{num} - \S", lines[0]):
        fail("lessons", f"{f}: first line must be '# L{num} - <title>'")
        return None
    if len(lines) < 2 or lines[1].strip() != LESSON_SWITCH[lang].format(stem):
        fail("lessons", f"{f}: second line must be {LESSON_SWITCH[lang].format(stem)}")
        return None
    head = table_rows("\n".join(lines[2:5]))
    if not (len(lines) > 5 and len(head) == 2 and re.fullmatch(r"\|[\s:|-]+\|", lines[3].strip())
            and not lines[5].lstrip().startswith("|")):
        fail("lessons", f"{f}: the language switch must be followed by the header table "
                        f"(header row, separator, exactly one data row)")
        return None
    if head[0] != LESSON_HEAD[lang]:
        fail("lessons", f"{f}: header table columns must be {LESSON_HEAD[lang]}, not {head[0]}")
        return None
    cells = head[1]
    if len(cells) != 4:
        fail("lessons", f"{f}: header table data row needs 4 cells")
        return None
    order, body = lesson_sections(prose)
    if order != LESSON_SECTIONS[lang]:
        fail("lessons", f"{f}: '##' sections must be exactly {LESSON_SECTIONS[lang]}, found {order}")
    # self-check: numbered questions, each with one folded answer
    sc = body.get(LESSON_SECTIONS[lang][6], [])
    questions = [l for l in sc if re.match(r"^\d+[.)]\s", l)]
    opened = [l for l in sc if "<details>" in l]
    closed = [l for l in sc if "</details>" in l]
    summaries = re.findall(r"<summary>(.*?)</summary>", "\n".join(sc))
    if not questions:
        fail("lessons", f"{f}: {LESSON_SECTIONS[lang][6]}: no numbered questions")
    if not (len(questions) == len(opened) == len(closed) == len(summaries)):
        fail("lessons", f"{f}: {LESSON_SECTIONS[lang][6]}: {len(questions)} questions, "
                        f"{len(opened)} <details>, {len(closed)} </details>, {len(summaries)} "
                        f"<summary> - every question needs exactly one folded answer")
    outside = [l for l in prose if re.search(r"</?details>", l) and l not in sc]
    if outside:
        fail("lessons", f"{f}: <details> outside {LESSON_SECTIONS[lang][6]} (also in comments): "
                        f"'lab lesson' hides everything between <details> and </details>")
    wrong = [s for s in summaries if s.strip() != LESSON_ANSWER[lang]]
    if wrong:
        fail("lessons", f"{f}: {LESSON_SECTIONS[lang][6]}: summary must be '{LESSON_ANSWER[lang]}', "
                        f"not {wrong}")
    if template:
        return None  # placeholder values
    where = f"{f}: header table"
    ex = lesson_list(where, LESSON_HEAD[lang][0], cells[0], ID_RE, exs_known, id_key)
    lesson_list(where, LESSON_HEAD[lang][1], cells[1], CIS_ID_RE, controls, id_key)
    if not LESSON_TIME_RE[lang].match(cells[2]):
        fail("lessons", f"{where}: {LESSON_HEAD[lang][2]} must look like "
                        f"{'~20 min' if lang == 'en' else '~20 Min.'}, not '{cells[2]}'")
    deps = lesson_list(where, LESSON_HEAD[lang][3], cells[3], LESSON_ID_RE, lessons, lambda x: x)
    later = [d for d in deps or [] if d >= f"L{num}"]
    if later:
        fail("lessons", f"{where}: {LESSON_HEAD[lang][3]}: {later} - only earlier lessons")
    # the exercises table lists exactly the header's exercises, in the same order
    if ex is not None:
        rows = table_rows("\n".join(body.get(LESSON_SECTIONS[lang][5], [])))
        listed = []
        for row in rows[1:]:
            lm = re.match(r"^\[([^\]]+)\]\(", row[0])
            listed.append(lm.group(1) if lm else row[0])
        if listed != ex:
            fail("lessons", f"{f}: {LESSON_SECTIONS[lang][5]}: table lists {listed}, header table "
                            f"says {ex}")
    return cells


def check_lessons(files, exs):
    paths = [f for f in files if f.startswith(LESSON_DIR + "/") and f.endswith(".md")]
    nested = [f for f in paths if f.count("/") != LESSON_DIR.count("/") + 1]
    for f in nested:
        fail("lessons", f"{f}: lessons live directly in {LESSON_DIR}/")
    paths = [f for f in paths if f not in nested]
    lessons = {}
    for f in paths:
        m = LESSON_NAME_RE.match(os.path.basename(f).split(".")[0])
        if m and not f.endswith(".de.md"):
            lid = f"L{m.group(1)}"
            if lid in lessons:
                fail("lessons", f"{f}: lesson number {lid} also used by {lessons[lid]}")
            lessons[lid] = f
    if paths and f"{LESSON_DIR}/{LESSON_TEMPLATE}.md" not in paths:
        fail("lessons", f"{LESSON_DIR}/{LESSON_TEMPLATE}.md missing")
    known = {m.get("id") for _, m in exs}
    controls = control_ids()
    heads = {}
    for f in sorted(paths):
        heads[f] = check_lesson(f, known, controls, lessons)
    for f, en in heads.items():
        de = heads.get(f[:-3] + ".de.md") if not f.endswith(".de.md") else None
        if en is None or de is None:
            continue
        tn, td = LESSON_TIME_RE["en"].match(en[2]), LESSON_TIME_RE["de"].match(de[2])
        if (en[0], en[1], en[3]) != (de[0], de[1], de[3]) or (tn and td and tn.group(1) != td.group(1)):
            fail("lessons", f"{f} vs {f[:-3]}.de.md: header table values differ: {en} vs {de}")


# --------------------------------------------------------------------------- main

CHECKS = ("meta", "parity", "links", "controls", "lessons")


def main(argv):
    wanted = argv or list(CHECKS)
    unknown = [a for a in wanted if a not in CHECKS]
    if unknown:
        print(f"unknown check(s): {unknown}; choose from {list(CHECKS)}", file=sys.stderr)
        return 2
    files = tracked_files()
    if "meta" not in wanted:
        quiet.add("meta")
    exs = check_meta() if {"meta", "controls", "lessons"} & set(wanted) else []
    if "parity" in wanted:
        check_parity(files)
    if "links" in wanted:
        check_links(files)
    if "controls" in wanted:
        check_controls(exs)
    if "lessons" in wanted:
        check_lessons(files, exs)
    for c in wanted if len(wanted) > 1 else []:
        print(f"{'FAIL' if failures[c] else 'ok  '} {c}" + (f" ({failures[c]})" if failures[c] else ""))
    return 1 if any(failures[c] for c in wanted) else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
