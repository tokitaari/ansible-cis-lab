# 3.04 - auditd: Regeln und Log-Aufbewahrung (Level 2): Erklärung

### Datengetriebene Regeldateien
Ein Dict, ein Template, eine Schleife. Ein Thema hinzufügen = einen Schlüssel
hinzufügen. Ein Thema entfernen braucht einen Aufräum-Task (`find` + `file: state=absent`
für `50-cis-*.rules`, die nicht im Dict stehen) - eine schöne Erweiterung.

### Was die Regeln erfassen
| Schlüssel | Frage, die er im Vorfall beantwortet |
|---|---|
| `scope`, `sudo_log_file` | wer hat sudo-Rechte geändert / das sudo-Log manipuliert? |
| `user_emulation` | wer hat Befehle als *anderer* Benutzer ausgeführt? |
| `time-change` | hat jemand die Uhr verstellt, um Log-Korrelation zu verwirren? |
| `identity` | wer hat Konten, PAM oder Namensauflösung angelegt/geändert? |
| `logins` | wurden Login-Aufzeichnungen angefasst? |
`-k` setzt den Schlüssel, nach dem du später suchst: `ausearch -k identity`.

### `-e 2`
Macht den Regelsatz bis zum Neustart unveränderlich - ein Angreifer mit root kann nicht
einfach `auditctl -D` ausführen. Es muss die *letzte* geladene Regel sein, daher `99-`.

### Entscheidungen in auditd.conf
- `keep_logs` - rotieren ohne zu löschen (Plattenplanung wird deine Aufgabe!).
- `space_left_action = email` → Frühwarnung; `admin_space_left_action = single` →
  lieber das System anhalten als ohne Audit weiterlaufen. Das ist eine
  Geschäftsentscheidung; L2 heißt "du akzeptierst diesen Kompromiss".

### Die Container-Lektion
Kernel-Funktionen fallen in zwei Gruppen: namespaced (Netzwerk, Mounts, PIDs, manche
sysctls) und global (Audit, Module, die meisten `kernel.*`). Container isolieren nur die
erste Gruppe. Härtungscode braucht einen Schalter für Umgebungen, in denen er die zweite
Gruppe nicht anfassen darf - genau das bildet `lab_in_container` ab.

## Musterlösung

Anzeigen mit `lab solution 3.04`, anwenden mit `lab solve 3.04`.
