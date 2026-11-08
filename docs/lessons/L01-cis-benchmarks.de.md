# L01 - CIS Benchmarks: Aufbau, Levels und der Lab-Katalog

*[English](L01-cis-benchmarks.md)*

| Übungen | CIS-Abschnitte | Lesezeit | Baut auf |
|---|---|---|---|
| - | - | ~25 Min. | L00 |

Jede Übung dieses Labs nennt in ihrem Kopf einen CIS-Abschnitt; diese Lektion erklärt, was
hinter diesem Verweis steckt - wie ein CIS Benchmark entsteht und gegliedert ist, was Level 1
und Level 2 bedeuten, wie aus einer Empfehlung ein Ansible-Task wird und wie der eigene Katalog
des Labs die Übungen mit den offiziellen PDFs verbindet.

## Lernziele

Nach dieser Lektion kannst du ...

- [ ] erklären, was ein CIS Benchmark ist, wer ihn schreibt und warum du ihn nicht in ein Repository kopieren darfst
- [ ] eine Empfehlung lesen: Profil, Audit- und Remediation-Teil sowie Auswirkungen finden
- [ ] *Automated*- von *Manual*-Empfehlungen unterscheiden und begründen, warum beide zählen
- [ ] zwischen Level 1 und Level 2 sowie zwischen Server- und Workstation-Profil wählen
- [ ] Audit- und Remediation-Teil einer Empfehlung auf Ansible-Tasks abbilden und wissen, was sich nicht automatisieren lässt
- [ ] mit `cis/controls.yml` und dem CIS-Verweis einer Übung das passende Kapitel eines Benchmarks finden

## Theorie

### Was ein CIS Benchmark ist

Das Center for Internet Security (CIS) ist eine gemeinnützige Organisation. Seine
**Benchmarks** sind sichere Konfigurations-Baselines für ein Produkt in einer Version:
"Ubuntu Linux 24.04 LTS", "Red Hat Enterprise Linux 9", aber auch Browser, Datenbanken,
Cloud-Konten und Netzwerkgeräte. Ein Benchmark beschreibt nicht allgemein, *was* zu schützen
ist; er sagt, *welche Einstellung* auf diesem Produkt zu wählen ist und wie man sie prüft.

Benchmarks entstehen in einem **Konsensverfahren**: CIS und ehrenamtliche Fachleute erstellen
einen Entwurf, die Community testet und kommentiert ihn, CIS arbeitet das Feedback ein, und
nach einer abschließenden Review-Runde wird der Benchmark veröffentlicht. Neue Versionen folgen,
wenn sich das Produkt oder die Bedrohungslage ändert. Das Ergebnis ist eine Baseline, die
viele Organisationen als "angemessen" akzeptieren - deshalb fragen Auditoren, Versicherer und
Sicherheitsfragebögen danach.

Drei verwandte Dinge werden leicht verwechselt:

| Name | Was es ist | Bezug zu den Benchmarks |
|---|---|---|
| CIS Controls (v8.1) | 18 produktunabhängige Sicherheitsmaßnahmen, gruppiert in Implementation Groups IG1-IG3 | jede Empfehlung eines Benchmarks verweist auf die Safeguards der Controls, die sie unterstützt |
| CIS-CAT | Prüfwerkzeug (Lite kostenlos, Pro für Mitglieder) | bewertet die *Automated*-Empfehlungen eines Benchmarks und berechnet einen Score |
| CIS Hardened Images | vorgehärtete Cloud-Images | ein von CIS angewendetes Benchmark-Profil, vertrieben über Cloud-Marktplätze |

Die PDFs sind nach einer Registrierung kostenlos, ihre Nutzungsbedingungen erlauben aber keine
Weitergabe. Deshalb enthält dieses Lab keinen CIS-Text: Lade die Benchmarks selbst herunter, wie
in [der CIS-README](../../cis/README.de.md) beschrieben, lege sie in `cis/pdf/` ab (von Git
ignoriert) und verwende in Code, Kommentaren und Dokumentation eigene Formulierungen.

### Aufbau einer Empfehlung

Ein Linux-Benchmark ist in Abschnitte gegliedert. Seit 2024 haben die Linux-Benchmarks diese
gemeinsame oberste Ebene, die auch [der Control-Katalog](../../cis/controls.yml) verwendet:

| Abschnitt | Thema | Beispiele im Lab |
|---|---|---|
| 1 | Initial setup | Kernel-Module, Prozesshärtung, Banner |
| 2 | Services | Server- und Client-Dienste, Cron |
| 3 | Network | Netzwerk-Kernel-Module und -Parameter |
| 4 | Host based firewall | nftables |
| 5 | Access control | SSH, sudo, PAM, Shadow-Suite, Konten |
| 6 | Logging and auditing | AIDE, Logging, auditd |
| 7 | System maintenance | Dateirechte, Benutzer und Gruppen |

Darunter verschachteln sich die Abschnitte (5 Access control → 5.1 SSH server → 5.1.x ein
sshd-Parameter). Das Blatt ist eine **Empfehlung** (Recommendation), und jede Empfehlung hat
dieselben Felder:

| Feld | Inhalt | Warum es dich interessiert |
|---|---|---|
| Title | der Zielzustand in einer Zeile, mit dem Bewertungsstatus | was zu erreichen ist |
| Profile applicability | Level 1 / Level 2, Server / Workstation | ob sie für dich gilt |
| Description, Rationale | was die Einstellung bewirkt, welchen Angriff sie begrenzt | das Argument in einer Ausnahme-Diskussion |
| Impact | was kaputtgehen kann | das Risiko der Anwendung |
| Audit | Befehle und erwartete Ausgabe | was dein Check beweisen muss |
| Remediation | wie der Zustand erreicht wird | was dein durchsetzender Task tut |
| Default value | der Standard der Distribution | was ein frischer Host zeigt |
| References, CIS Controls | Manpages, Zuordnung zu Safeguards der Controls | Kontext, Reporting |

Der **Bewertungsstatus** (Assessment Status) im Titel ist entweder *Automated* oder *Manual*
(bis Ende 2020 hießen sie *Scored* und *Not Scored*). *Automated* heißt: Ein Werkzeug kann das
System mit dem erwarteten Zustand vergleichen und liefert bestanden oder nicht bestanden.
*Manual* heißt: Ein Mensch muss es beurteilen - etwa ob die Liste der erlaubten SSH-Benutzer für
diesen Host die richtige ist. CIS-CAT lässt Manual-Empfehlungen aus dem Score heraus, optional
sind sie trotzdem nicht: Eine leere oder falsche Allow-List ist ebenso ein Befund wie ein
falscher Dateimodus.

**Nummern wandern.** Empfehlungsnummern unterscheiden sich zwischen Distributionen und ändern
sich zwischen Versionen desselben Benchmarks. Ältere Linux-Benchmarks hatten zum Beispiel
Logging und Auditing in Abschnitt 4 und Systemwartung in Abschnitt 6; die Struktur von 2024 gab
der Host-Firewall einen eigenen Abschnitt 4 und verschob diese beiden in die Abschnitte 6 und 7.
Das Lab verweist deshalb nur auf die stabilen oberen Ebenen (`5.1`, `6.3`) und überlässt die
genaue Nummer dem PDF deiner Distribution und Version.

### Profile und Levels

Nicht jede Härtungsmaßnahme passt zu jedem System. Jede Empfehlung nennt die **Profile**, zu
denen sie gehört. Linux-Benchmarks haben typischerweise vier:

| | Server | Workstation |
|---|---|---|
| **Level 1** | praxistaugliche Baseline für Server: klarer Sicherheitsgewinn, wenig Einfluss auf den Betrieb | dieselbe Idee für Desktops (grafische Sitzung, Wechseldatenträger in Gebrauch) |
| **Level 2** | ergänzt Defense-in-Depth-Maßnahmen für Umgebungen mit hohem Schutzbedarf; kann Funktionen einschränken oder Leistung kosten | dasselbe für Desktops |

Level 2 *erweitert* Level 1: Ein Level-2-System wendet alle Level-1-Empfehlungen an und
zusätzlich die Level-2-Empfehlungen. Typischer Level-2-Stoff sind umfangreiches Auditing, das
Abschalten selten genutzter Netzwerkprotokolle oder strengere Mount-Optionen - sinnvoll, wo der
Schutzbedarf die Kosten rechtfertigt, schädlich, wo niemand die Audit-Logs liest und die Platte
vollläuft.

Das Lab verwendet **Level 1 Server** als Baseline. Level 2 kommt nur vor, wo eine Übung es
sagt; im Katalog sind das 3.2 (seltene Netzwerkprotokolle) und 6.3 (auditd). Übungen mit
Level-2-Inhalt nehmen das Level als Variable `cis_level` entgegen (Standard 1), und die Checks
der kumulativen Rolle akzeptieren sie ebenfalls:

```bash
lab check 4.03 -e cis_level=2
```

Wie eine Rolle einen solchen Schalter umsetzt - und wie sie bewusste Ausnahmen festhält - ist
Thema von Übung 4.02 und Lektion L11.

### Von der Empfehlung zur Automatisierung

Die beiden praktischen Felder einer Empfehlung entsprechen direkt zwei Arten von Ansible-Tasks:

| Empfehlung | Ansible | Lab |
|---|---|---|
| Audit | lesende Tasks, die eine Abweichung melden (`register`, `assert`, Check-Mode) | jedes `lab check`, Übung 4.01 (reiner Audit-Report) |
| Remediation | Tasks, die den Zielzustand beschreiben (`lineinfile`, `template`, `file`, `package`) | jede Härtungsübung |
| Impact | `--check --diff` vor dem Anwenden, gestaffelter Rollout | 1.x (sichere Änderungen), 5.02 (Rollout) |
| Default value | was ein frisches Target zeigt | `./lab.sh reset <host>` |

Der Remediation-Text eines Benchmarks ist für einen Menschen an der Shell geschrieben: "Datei
bearbeiten und ... setzen", "... ausführen". Wer diese Befehle in `shell`-Tasks kopiert, erhält
ein Playbook, das bei jedem Lauf etwas ändert. Übersetze stattdessen den *Zielzustand*, damit
Ansible entscheiden kann, ob eine Änderung nötig ist (Lektion L00, Idempotenz).

Manche Empfehlungen lassen sich nicht vollständig automatisieren:

- **Manual**-Empfehlungen brauchen eine Entscheidung - welche Benutzer sich anmelden dürfen,
  welche Dienste nötig sind. Ansible kann die Entscheidung durchsetzen, sobald sie als Daten
  festgehalten ist, sie aber nicht treffen.
- **Standortspezifische Werte** (erlaubte Netze, Log-Server, Bannertext) gehören in Variablen,
  nicht in Tasks.
- **Ausnahmen** sind normal: Keine Organisation setzt einen Benchmark zu 100 % um. Entscheidend
  ist, dass jede Abweichung mit Begründung, Verantwortlichem und Ablaufdatum festgehalten wird -
  und dass die Automatisierung sie kennt, statt dass jemand die Änderung von Hand zurückdreht.

Und schließlich: Compliance ist nicht Sicherheit. Ein Host kann jede Automated-Empfehlung
erfüllen und trotzdem einen ungepatchten Dienst an einem öffentlichen Port betreiben. Ein
Benchmark ist eine Baseline zum Starten, kein Beweis, dass ein System sicher ist.

### Der Lab-Katalog: `controls.yml` und `meta.yml`

[`cis/controls.yml`](../../cis/controls.yml) ist der eigene Katalog des Labs, in eigenen Worten.
Ein Eintrag pro Control:

```yaml
- id: "5.1"
  section: 5 Access control / SSH server
  title: SSH hardened (no root login, limited auth tries, strong crypto, allow-list, timeouts, banner)
  level: 1
  container: full
  exercises: ["1.03", "2.02", "3.01", "5.01"]
  platforms: ssh vs sshd service name; first match wins; EL crypto-policies included after drop-ins
```

`id` und `section` verweisen auf die Benchmark-Struktur, `level` auf das Profil, `exercises` auf
die Übungen, die das Control umsetzen, und `platforms` auf Unterschiede zwischen den
Distributionen. `container` sagt, wie weit das Lab die Wirkung zeigen kann (siehe *In den
Lab-Containern* unten).

Die Gegenrichtung steht in jeder Übung: Ihre `meta.yml` hat einen Eintrag `cis` mit Abschnitt
und Level, der als *CIS-Bezug* im Kopf der README und in `lab list` erscheint. Der Weg von einer
Übung zum Benchmark ist also: CIS-Bezug der Übung → Eintrag in `controls.yml`
(Plattformhinweise) → Kapitel im PDF deiner Distribution.

Der Katalog ist einfaches YAML, also kann Ansible ihn abfragen. Dieses Play läuft nur auf dem
Control-Node und ändert nichts:

```yaml
- name: Query the lab control catalogue
  hosts: localhost
  gather_facts: false
  vars:
    catalogue: "{{ lookup('ansible.builtin.file', '/lab/cis/controls.yml') | from_yaml }}"
  tasks:
    - name: List the Level 2 controls
      ansible.builtin.debug:
        msg: "{{ catalogue.controls | selectattr('level', '==', 2) | map(attribute='id') | list }}"

    - name: List the controls the containers cannot reproduce
      ansible.builtin.debug:
        msg: "{{ catalogue.controls | selectattr('container', '==', 'no') | map(attribute='id') | list }}"

    - name: Show which exercises implement section 5.1
      ansible.builtin.debug:
        msg: "{{ (catalogue.controls | selectattr('id', '==', '5.1') | first).exercises }}"
```

Speichere es als `/lab/work/demo/catalogue.yml` und starte dort `ansible-playbook catalogue.yml`.
Der erste Task gibt `3.2` und `6.3` aus, der zweite `1.1.2`, `1.3` und `1.4`. Die Ids sind im
Katalog Strings - vergleiche mit `'5.1'`, nicht mit der Zahl `5.1`. `selectattr` und die übrigen
Filter musst du noch nicht verstehen; Lektion L04 behandelt sie. Das statische Gate
(`tools/static-check.sh controls`) hält beide Richtungen konsistent: Eine Übung, deren
`cis`-Abschnitt eine Katalog-Id nennt, muss in den `exercises` dieses Controls stehen.

## CIS-Hintergrund

Warum sind Benchmarks über das Lab hinaus wichtig? Weil sie die gemeinsame Sprache von
Administratoren und Auditoren sind. "Wir folgen CIS Level 1 Server mit diesen 12 dokumentierten
Ausnahmen" ist eine Aussage, die ein Prüfer nachvollziehen kann; "unsere Server sind gehärtet"
nicht. Standards wie PCI DSS verlangen einen Konfigurationsstandard für Systemkomponenten und
nennen Branchen-Baselines wie CIS als eine Quelle; interne Richtlinien verweisen oft mit Name und
Version auf einen Benchmark.

Andere Baselines decken dasselbe Gebiet ab: Die DISA STIGs (US-Verteidigungsministerium) sind
strenger und detaillierter vorgeschrieben, und in Deutschland beschreibt das
IT-Grundschutz-Kompendium des BSI im Baustein SYS.1.3 Anforderungen an Linux-Server. Inhaltlich
überschneiden sie sich mit CIS, unterscheiden sich aber in Nummerierung, Wortlaut und Strenge.
Folgt deine Organisation einer davon, bleiben die Techniken dieses Labs dieselben - nur der
Katalog wechselt.

Der Wert eines Benchmarks liegt ebenso in den Feldern *Rationale* und *Impact* wie in den
Einstellungen: Mit ihnen begründest du eine Maßnahme - und widersprichst ihr, wo sie nicht passt.

## Plattformunterschiede

| os_family | Hosts | Zu verwendender Benchmark | Hinweis |
|---|---|---|---|
| Debian | debian, ubuntu | Debian Linux, Ubuntu Linux (je LTS) | getrennte Benchmarks, Nummerierung unterscheidet sich |
| RedHat | rocky, alma, fedora | Rocky Linux, AlmaLinux OS, Red Hat Enterprise Linux | kein aktueller Fedora-Benchmark: den RHEL-Benchmark als nächste Referenz nehmen |
| Suse | opensuse | SUSE Linux Enterprise | openSUSE Leap teilt die Codebasis |
| Alpine | alpine | keiner | Controls selbst zuordnen; viele sind nicht anwendbar (kein PAM, busybox) |
| Archlinux | arch | keiner | Controls selbst zuordnen |

Die herunterzuladenden Versionen stehen in [der CIS-README](../../cis/README.de.md). Controls
einer Plattform ohne Benchmark zuzuordnen gehört zum Training: Die Absicht einer Empfehlung (die
Rationale) lässt sich übertragen, Befehle und Dateinamen nicht.

### In den Lab-Containern

Die Targets sind Container auf einem gemeinsamen Kernel (Lektion L00), daher lässt sich nicht
jedes Control gleich üben. Das Feld `container` jedes Katalogeintrags sagt, wie weit es geht:

| Wert | Bedeutung | Beispiele |
|---|---|---|
| `full` | in den Containern konfigurieren und prüfen | SSH, sudo, Dateirechte |
| `config` | Konfiguration schreiben; die Wirkung ist kernel- oder hostweit und wird nicht aktiviert | Kernel-Module, globale sysctls, auditd |
| `no` | in Containern nicht nachstellbar - Theorie oder echte VM | Partitionen, MAC (SELinux/AppArmor), Bootloader |

Details pro Control stehen in [den Container-Grenzen](../CONTAINER_LIMITS.de.md).

## Stolperfallen

| Symptom | Ursache | Lösung |
|---|---|---|
| Die Nummer im Scanner-Report passt nicht zu deinem PDF | andere Benchmark-Version oder Distribution | Titel vergleichen, nicht Nummern; Benchmark-Name und -Version in Reports und Code festhalten |
| Ein Level-2-Rollout legt eine Anwendung lahm oder füllt eine Platte | Level 2 angewendet, ohne *Impact* zu lesen | Level pro Systemklasse wählen, zuerst auf einem Canary testen |
| 100 % Score, aber ein Prüfer findet trotzdem Probleme | der Score umfasst nur *Automated*-Empfehlungen | die Manual-Empfehlungen prüfen und die Entscheidungen als Daten festhalten |
| Ein Playbook meldet bei jedem Lauf `changed` | Remediation-Befehle in `shell`-Tasks kopiert | den Zielzustand mit Zustandsmodulen beschreiben |
| Benchmark-Text im eigenen Repository oder Wiki | Lizenzbedingungen verbieten die Weitergabe | eigene Formulierungen, Verweis über Abschnittsnummer und Titel |
| Eine Änderung auf einem Host wird vom nächsten Lauf zurückgedreht | die Ausnahme existiert nur in jemandes Kopf | Ausnahmen mit Begründung, Verantwortlichem und Ablaufdatum dort festhalten, wo die Automatisierung sie liest |

## Übungen

Diese Lektion hat keine eigene Übung: Sie ist der Hintergrund für alle. Jede Übung nennt ihren
CIS-Abschnitt und ihr Level im Kopf der README und in `lab list`; schlage den Abschnitt vor dem
Start in `cis/controls.yml` nach. Drei Übungen arbeiten direkt mit den Konzepten:
[4.01](../../exercises/stage4-advanced/4.01-audit-only-report/README.de.md) (Audit ohne
Remediation),
[4.02](../../exercises/stage4-advanced/4.02-profiles-and-exceptions/README.de.md) (Level 1/2 und
dokumentierte Ausnahmen) und
[5.03](../../exercises/stage5-capstone/5.03-compare-with-community-role/README.de.md) (Review
einer Community-CIS-Rolle).

Starte eine Übung mit `lab start <id>`; `lab show <id>` zeigt ihre README.

## Selbstkontrolle

1. Ein Scanner meldet für einen Ubuntu-Host "5.2.4 failed". In deinem PDF steht unter 5.2.4
   etwas anderes. Wer liegt falsch?

   <details><summary>Antwort</summary>

   Wahrscheinlich niemand: Scanner und PDF verwenden unterschiedliche Benchmark-Versionen (oder
   der Scanner den Benchmark einer anderen Distribution). Nummern sind nur zusammen mit
   Benchmark-Name und -Version aussagekräftig. Vergleiche Titel und Audit-Verfahren und halte
   die Version in Reports fest.

   </details>

2. Deine Vorgesetzte möchte "100 % CIS-Compliance" mit einem CIS-CAT-Report belegt haben. Warum
   reicht der Report nicht?

   <details><summary>Antwort</summary>

   Der Score umfasst nur die *Automated*-Empfehlungen. *Manual*-Empfehlungen (Allow-Lists,
   welche Dienste nötig sind) brauchen eine dokumentierte menschliche Entscheidung, und jede
   bewusste Abweichung braucht eine festgehaltene Ausnahme. Außerdem beweist die Einhaltung einer
   Baseline keine Sicherheit - Patchen und Exposition liegen außerhalb eines
   Konfigurations-Benchmarks.

   </details>

3. Ein Datenbankserver und ein Jump-Host für Administratoren - von welchem Profil gehst du
   jeweils aus, und warum?

   <details><summary>Antwort</summary>

   Beides sind Server, also ein Server-Profil. Level 1 ist der Standard für den Datenbankserver;
   Level-2-Maßnahmen (umfangreiches Auditing, strengere Einschränkungen) lohnen ihre Kosten auf
   dem Jump-Host, einem besonders wertvollen Angriffsziel - vorausgesetzt, jemand wertet die
   Audit-Logs aus. Die Entscheidung folgt dem Schutzbedarf und dem *Impact* der
   Level-2-Empfehlungen.

   </details>

4. Die Remediation einer Empfehlung lautet: "Folgenden Befehl ausführen und die Datei so
   bearbeiten, dass ...". Warum gehört dieser Befehl nicht in einen `ansible.builtin.shell`-Task?

   <details><summary>Antwort</summary>

   Ein Shell-Befehl kann nicht erkennen, ob der Zustand schon erreicht ist, also ändert der Task
   bei jedem Lauf etwas (oder meldet zumindest `changed`), und `--check` kann ihn nicht
   vorhersagen. Übersetze den Zielzustand in ein Zustandsmodul (`lineinfile`, `template`,
   `file`, ...); dann meldet der zweite Lauf keine Änderung, und das Playbook taugt zugleich als
   Compliance-Check.

   </details>

5. Control 6.3 (auditd) hat im Katalog `container: config`. Was bedeutet das für die Übungen,
   die es umsetzen?

   <details><summary>Antwort</summary>

   Die Übungen schreiben Audit-Regeln und Einstellungen und prüfen die Dateien, laden die Regeln
   aber nicht und starten auditd nicht: Das Audit-Subsystem gehört zum gemeinsamen Host-Kernel,
   eine Aktivierung im Container würde den Docker-Host und alle anderen Container betreffen.

   </details>

6. Für Arch Linux gibt es keinen CIS Benchmark. Wie entscheidest du, was auf dem Target `arch`
   angewendet wird?

   <details><summary>Antwort</summary>

   Gehe von einem Benchmark einer ähnlichen Distribution (oder vom Lab-Katalog) aus, übernimm die
   *Absicht* jeder Empfehlung aus ihrer Rationale und suche dann die Arch-spezifischen
   Paketnamen, Dateipfade und Werkzeuge. Dokumentiere, wo ein Control nicht anwendbar ist oder
   anders umgesetzt wird - dieselbe Arbeit wie für jede Plattform ohne Benchmark.

   </details>

## Weiterführendes

- [CIS Benchmarks](https://www.cisecurity.org/cis-benchmarks) - Liste aller Benchmarks und Download
- [The CIS Benchmarks community consensus process](https://www.cisecurity.org/insights/blog/the-cis-benchmarks-community-consensus-process)
- [Changes to CIS Benchmark assessment/recommendation scoring](https://www.cisecurity.org/insights/blog/changes-to-cis-benchmark-assessment-recommendation-scoring) - Automated und Manual
- [CIS Critical Security Controls](https://www.cisecurity.org/controls)
- [Working with lookups](https://docs.ansible.com/projects/ansible/latest/plugins/lookup.html) und [Using filters to manipulate data](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_filters.html)
- [Glossar](../GLOSSARY.de.md) - Begriffe dieser Lektion: Automated / Manual, CIS Benchmark,
  CIS Controls, CIS-CAT, control (lab catalogue), Level 1 / Level 2, profile (CIS),
  recommendation (CIS), `requires` (meta.yml)
