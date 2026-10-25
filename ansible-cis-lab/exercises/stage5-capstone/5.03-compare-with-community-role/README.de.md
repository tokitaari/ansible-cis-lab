# 5.03 - Review: deine Rolle vs. eine Community-CIS-Rolle

*[English](README.md)*

| Stufe | Schwierigkeit | Zeit | CIS-Bezug | Hosts |
|---|---|---|---|---|
| Stufe 5 - Abschlussprojekt | ★★★★☆ | ~90 Min. | all (L1/L2) | `(reading)` |

**Konzepte:** `code review`, `benchmark coverage`, `build vs. buy`

## Ziel

Lies eine ausgereifte Open-Source-CIS-Rolle kritisch und entscheide - mit Argumenten -, was du übernehmen, was du selbst bauen und was du nie ungeprüft ausführen würdest.

## Hintergrund

Das Projekt *ansible-lockdown* (GitHub-Organisation `ansible-lockdown`) pflegt CIS- und
STIG-Rollen pro Distribution, z. B. für RHEL, Ubuntu, Debian. Sie setzen mehrere hundert
Kontrollen um, mit Schaltern pro Kontrolle und einer Audit-Komponente. Nachdem du selbst
eine kleinere Version gebaut hast, kannst du sie mit Expertenblick lesen.

Wähle die Rolle, die zu einer der Lab-Plattformen passt. Klone sie auf dem Control Node
(`git clone` funktioniert dort) nach `/lab/work/5.03/`. Du darfst sie im `--check`-Modus
gegen einen frisch zurückgesetzten Host laufen lassen - nie im Enforce-Modus, ohne zu
lesen, was sie tut.

## Anforderungen

- [ ] Schreibe `/lab/work/5.03/review.md` mit Antworten auf die Fragen unten (je mindestens ein kurzer Absatz).
- [ ] 1. Wie schaltet die Rolle einzelne Kontrollen ein/aus? Vergleiche mit deinem Registry-/Ausnahme-Design.
- [ ] 2. Wie behandelt sie Level 1 vs. Level 2 und Server vs. Workstation?
- [ ] 3. Welche Kontrollen sind standardmäßig deaktiviert, und warum könnten die Maintainer das so entschieden haben?
- [ ] 4. Finde zwei Kontrollen, die dich aussperren oder eine Anwendung kaputt machen könnten. Wie sind sie abgesichert?
- [ ] 5. Wie auditiert sie (Check-Modus? separates Werkzeug?) und wie berichtet sie?
- [ ] 6. Deine Entscheidung für eine Umgebung mit 500 Servern: übernehmen, forken oder selbst bauen - und welche Abnahmetests hättest du?

## Vorgehen

```bash
lab start 5.03            # legt /lab/work/5.03/ an
cd /lab/work/5.03
# playbook.yml schreiben, dann ausführen:
ansible-playbook playbook.yml
lab check 5.03            # prüft den Zustand
```

Festgefahren? `lab hint 5.03 1` (sanft) ... `lab hint 5.03 3` (fast die Lösung).  
Bestanden? Lies `lab explain 5.03` - dort stehen Stolperfallen und Praxis-Hinweise.
Host kaputt? `./lab.sh reset <host>` auf dem Host stellt ihn wieder her.

## Bonus (optional)

- Lass sie mit `--check --diff` gegen einen frisch zurückgesetzten Host laufen und zähle die beabsichtigten Änderungen. Vergleiche mit deinem eigenen Audit-Bericht aus 5.01.
- Sieh dir die CI des Projekts an: welche Plattformen und Szenarien werden bei jeder Änderung getestet?
