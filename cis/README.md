# CIS benchmarks

*[Deutsch](README.de.md)*

The official CIS Benchmark PDFs are **not** part of this lab: CIS distributes them free of
charge after registration, under terms that do not allow redistribution. Download them
yourself and place them in `cis/pdf/` (ignored by Git).

## Where to get them

1. <https://www.cisecurity.org/cis-benchmarks> → *Operating Systems* → *Linux*.
2. Register (free) and download the PDF for each platform you train on.
3. Use the **Level 1 - Server** profile as reference; this lab uses Level 2 only where noted.

| Lab host | Benchmark to download | Note |
|---|---|---|
| debian | Debian Linux (matching major version) | |
| ubuntu | Ubuntu Linux (matching LTS) | |
| rocky | Rocky Linux (matching major version) | |
| alma | AlmaLinux OS (matching major version) | |
| fedora | - (no Fedora benchmark) | use the Red Hat Enterprise Linux benchmark as the closest reference |
| opensuse | SUSE Linux Enterprise | openSUSE Leap shares the code base |
| arch | - | map controls yourself - that is part of the training |
| alpine | - | map controls yourself; many controls are N/A (no PAM, busybox) |

Suggested file names: `cis/pdf/<platform>-<version>-v<benchmark-version>.pdf`.
Check the release notes of each benchmark version - recommendation numbers can change between versions.

## controls.yml

[`controls.yml`](controls.yml) is the lab's own catalogue (own wording, no CIS text). For
each control it lists the CIS section, the profile level, whether it can be practised in
containers (`full` / `config` / `no`) and which exercises implement it. Use it to jump
between an exercise and the matching chapter of the PDF.
