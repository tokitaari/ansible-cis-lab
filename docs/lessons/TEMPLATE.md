# LNN - Lesson title

*[Deutsch](TEMPLATE.de.md)*

| Exercises | CIS sections | Reading time | Builds on |
|---|---|---|---|
| x.yy, x.yy | n.n, n.n | ~20 min | L00 |

<!--
Template for the self-study lessons in docs/lessons/. Copy it to LNN-slug.md and
LNN-slug.de.md (NN = two digits, slug = lowercase words joined by '-'), then replace every
italic placeholder. tools/static-check.sh lessons enforces the structure:

- line 1 is '# LNN - <title>' with NN from the file name, then the language switch line,
  then the header table above (same values in EN and DE, only the time unit differs)
- Exercises: exercise ids, sorted, comma-separated, or '-'; the same ids (and only those)
  appear in the table of the Exercises section
- CIS sections: ids from cis/controls.yml, sorted, comma-separated, or '-'
- Reading time: '~N min' (DE '~N Min.'), aim for 15-30 minutes
- Builds on: earlier lessons that exist (L00, L03), sorted, or '-'
- exactly the eight '##' sections of this template, in this order, with these titles;
  use '###' and deeper inside them as needed
- Self-check: numbered questions, each followed by one folded details block whose summary is
  'Answer' (DE 'Antwort')

Writing rules:
- A lesson explains concepts BEFORE the exercises. Never show an exercise's reference
  solution or a solution to its requirements - that is what EXPLANATION.md is for.
- Examples are small and generic (one task, one host group) and different from the solution.
- CIS: own wording only, never benchmark text. Name recommendation numbers by the section
  ids used in cis/controls.yml; exact numbers differ per benchmark and version.
- Platform values as in the facts: os_family Debian, RedHat, Suse, Alpine, Archlinux.
- Tagged code blocks (yaml, bash) hold identical code in EN and DE, task 'name:' values
  included (keep them English); only '#' comments are translated.
- Every relative link must resolve (static-check links); link exercises to their README.md.
- Write the details tag only in the self-check: a hidden-answers view cuts from the first
  opening tag to the next closing tag, even inside this comment.
-->

*One or two sentences: which problem this lesson solves and why it matters for hardening.*

## Learning goals

After this lesson you can ...

- [ ] *verb + concept, e.g. explain why ...*
- [ ] *verb + concept, e.g. choose between ... and ...*
- [ ] *verb + concept, e.g. predict what `--check` reports for ...*

## Theory

### Concept 1

*The problem first, then the Ansible mechanism that solves it, then a minimal example.*

```yaml
- name: Minimal example of the mechanism
  hosts: targets
  tasks:
    - name: Show the idea
      ansible.builtin.debug:
        msg: "replace with a small, generic example - not the exercise solution"
```

*What the example shows, what it deliberately leaves out.*

### Concept 2

*Same pattern. Use as many concepts as the lesson needs, typically two to five.*

## CIS background

*What the recommendations protect against, why some are Level 2 only, typical
trade-offs in production. Refer to the ids from [the control catalogue](../../cis/controls.yml).*

## Platform differences

| os_family | *Aspect 1* | *Aspect 2* |
|---|---|---|
| Debian | | |
| RedHat | | |
| Suse | | |
| Alpine | | |
| Archlinux | | |

### In the lab containers

*What the containers cannot show and how the exercises deal with it -
see [container limits](../CONTAINER_LIMITS.md). Write "Nothing special" if that applies.*

## Pitfalls

| Symptom | Cause | Fix |
|---|---|---|
| *what the learner sees* | *why it happens* | *what to do instead* |

## Exercises

| Exercise | What this lesson prepares |
|---|---|
| [x.yy](../../exercises/INDEX.md) | *concepts from this lesson the exercise needs* |

Start an exercise with `lab start <id>`; `lab show <id>` prints its README.

## Self-check

1. *Question that tests understanding, not recall of a command.*

   <details><summary>Answer</summary>

   *Answer in two to five sentences.*

   </details>

2. *Question about a pitfall or a platform difference.*

   <details><summary>Answer</summary>

   *Answer.*

   </details>

## Further reading

- [Ansible documentation](https://docs.ansible.com/) - *the relevant module or guide page*
- *man page or upstream documentation of the configured tool*
