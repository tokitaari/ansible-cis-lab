# Einstufungstest

*[English](PLACEMENT.md)*

Zehn Fragen, etwa zehn Minuten. Antworte ehrlich, ohne nachzuschlagen, und vergleiche dann
mit dem Schlüssel unten. Die Punktzahl sagt dir, wo du einsteigst - zurückgehen geht immer.

**1.** Was testet `ansible all -m ansible.builtin.ping` tatsächlich?
a) ICMP-Erreichbarkeit b) SSH-Login + Ausführung eines Python-Moduls c) nur DNS-Auflösung

**2.** Warum schreibt man einen Dateimodus als `mode: "0644"` und nicht als `mode: 644`?

**3.** Ein Task kopiert eine Datei. Beim zweiten Lauf meldet er `ok` statt `changed`. Wie heißt diese Eigenschaft, und warum ist sie wichtig?

**4.** `telnet` soll auf Debian, Rocky und Alpine mit einem Task entfernt werden. Welches Modul?

**5.** Was unterscheidet einen Handler von einem normalen Task?

**6.** Ein Playbook muss auf Debian `apt` und auf Rocky `dnf` nutzen. Nenne zwei Wege, das auszudrücken, und welcher besser auf acht Distributionen skaliert.

**7.** Was ist der Unterschied zwischen `defaults/main.yml` und `vars/main.yml` in einer Rolle?

**8.** `import_tasks` vs. `include_tasks` - wann brauchst du die dynamische Variante?

**9.** Ein `command`-Task liest nur Daten. Was ergänzt du, damit er kein `changed` meldet und trotzdem unter `--check` läuft?

**10.** Wie würdest du eine Firewall-Änderung auf 500 Server ausrollen, ohne die ganze Flotte auszusperren? Nenne mindestens drei Techniken.

---

<details>
<summary>Lösungsschlüssel und Empfehlung</summary>

1. b) - 1 Punkt
2. YAML liest `644` als Dezimalzahl (= oktal 1204). - 1 Punkt
3. Idempotenz; wiederholte Läufe dürfen ein konformes System nicht ändern (Drift-Erkennung, sichere Wiederholung). - 1 Punkt
4. `ansible.builtin.package` mit `state: absent`. - 1 Punkt
5. Ein Handler läuft nur bei Benachrichtigung, einmal, am Ende des Plays (oder bei `flush_handlers`). - 1 Punkt
6. `when`-Bedingungen pro Familie vs. Variable/Dict-Lookup über `ansible_facts.os_family` (oder `package` + vars-Dateien). Datengetrieben skaliert besser. - 1 Punkt
7. defaults = niedrigster Vorrang, Stellschrauben für Nutzer; vars = hoher Vorrang, interne/Plattformdaten. - 1 Punkt
8. Wenn Dateiname oder Schleife erst zur Laufzeit feststehen (Variablen, Schleifen, Entscheidungen pro Host). - 1 Punkt
9. `changed_when: false` und `check_mode: false`. - 1 Punkt
10. Drei davon: vor dem Aktivieren validieren, Totmannschalter / automatischer Rollback, Canary-Hosts, `serial`-Wellen, `max_fail_percentage`, Vorabprüfung mit `any_errors_fatal`, Nachprüfung mit frischer Verbindung. - 1 Punkt

| Punkte | Starte mit | Tipp |
|---|---|---|
| 0-3 | **0.01** | Alle Aufgaben der Reihe nach, Hinweise ruhig nutzen. |
| 4-6 | **1.01** | Stufe 0 überfliegen, ihre Lösungen ausführen (`lab solve 0.02`, `lab solve 0.03`). |
| 7-8 | **2.01** | 0.02 erledigen (Alpine-Bootstrap wird später gebraucht), dann Stufe 2. |
| 9-10 | **3.01** | `lab solve` für 0.02 ... 2.06 ausführen, dann die Rolle bauen. Hinweise meiden. |

Egal, wo du startest: Aufgabe 0.02 muss einmal angewendet sein (Python auf Alpine), sonst
scheitern viele Checks auf dem Alpine-Host.
</details>
