# 4.02 - Profile (Level 1/2) und dokumentierte Ausnahmen: Erklärung

### Was der Check prüft
`lab check 4.02` startet dein Playbook fünfmal im `--check`-Modus auf `debian` (`-l debian`) mit
dem JSON-Callback und liest zwei Dinge: den Exit-Code jedes Laufs und je Task, ob er übersprungen
wurde. Eine Kontrolle "lief", wenn nicht alle Tasks übersprungen wurden, deren Name mit ihrer ID
beginnt; das Rollenpräfix (`cis_profile : `) wird abgeschnitten, Groß-/Kleinschreibung ist egal.
`meta.yml` sagt `idempotency: false`, also gibt es keinen zweiten Lauf. Der Check prüft:
- Level 1, Level 2 und der Lauf mit gültiger Ausnahme gelingen; eine abgelaufene Ausnahme und
  eine leere Begründung lassen den Lauf jeweils scheitern;
- Level 1: beide `l1-*`-Kontrollen laufen und kein `l2-*`-Task läuft;
- Level 2: beide `l2-*`-Kontrollen laufen;
- mit Ausnahme für `l2-modules`: seine Tasks werden übersprungen, `l2-audit-identity` läuft weiter.

Nicht geprüft werden: die Dateien und Pakete selbst (der Check-Modus ändert nichts), die Ausgabe,
die die ausgenommenen Kontrollen nennt, eine unbekannte ID und ein fehlendes `expires` (der Check
übergibt sie nie), dass die Validierung *vor* der ersten Kontrolle läuft, ein `cis_level` außer
1 und 2 und welcher Fehler einen Lauf gestoppt hat (jeder Exit-Code ungleich 0 genügt). Drei
davon hat das Verändern der Musterlösung bestätigt: Der Check blieb grün mit entferntem
Ausgabe-Task, mit der Validierung hinter beiden Level-2-Kontrollen und ohne die Prüfungen auf
unbekannte ID und fehlendes `expires`. Diese Teile des Vertrags musst du selbst richtig
umsetzen. Check und `lab solve` laufen nur auf `debian`, deshalb gibt es hier keinen Abschnitt
je Familie.

### So funktioniert es

#### Level als Wert, `when` an einem Block
```yaml
- name: L2-modules | Level 2 kernel modules
  when:
    - cis_level | int >= 2
    - "'l2-modules' not in cis_exception_ids"
  block:
    - name: L2-modules | Disable squashfs and udf
      ansible.builtin.copy: ...
```
`when` an einem Block wird an jeden Task vererbt, also erscheint eine übersprungene Kontrolle
als übersprungene Tasks in der Ausgabe und im JSON-Callback - genau das liest der Check.

Vergleiche den Level mit `| int`. Ein Wert aus `-e cis_level=2` ist ein String; ohne `| int`
bricht der Lauf mit `'>=' not supported between instances of '_AnsibleTaggedStr' and 'int'` ab.
Der Check übergibt seine Variablen als JSON, dort ist `2` eine Zahl, er warnt dich also nicht.

Nimm einen Block je Kontrolle und setze die Bedingung auf den Block. Ein Task mit Schleife, dessen
`when` von `item` abhängt und nur einige Elemente überspringt, gilt nicht als übersprungen: der
`skip_reason` steht in `results`, und der Check würde die Kontrolle als gelaufen zählen. Ein Task,
dessen Bedingung für alle Elemente falsch ist oder `item` nicht nutzt, wird als Ganzes übersprungen.

#### Eingaben validieren, bevor etwas angefasst wird
Härtungsrollen bekommen Eingaben von vielen Leuten (Inventar, CI-Variablen, `-e`). Eine falsch
geschriebene ID passt auf keine Kontrolle: die Ausnahme, die der Autor meinte, existiert nicht,
die Kontrolle läuft weiter und niemand erfährt es. Früh scheitern, mit einer Meldung, die den
Eintrag nennt. Das Datum macht aus einer vergessenen Ausnahme eine rote Pipeline statt eines
dauerhaften Lochs. Details der Musterlösung:
- `item.id | default('')` und `item.expires is defined` lassen einen Eintrag mit fehlendem Feld an
  der Prüfung scheitern; eine unbekannte ID, ein fehlendes `expires` und eine leere Begründung
  stoppen den Lauf jeweils mit derselben Meldung (gemessen).
- `| string | trim | length` für die Begründung: `length > 0` allein akzeptiert `" "`, und der Lauf
  gab eine leere Begründung aus und lief weiter (gemessen).
- Die Validierung ist der erste Task nach der Level-Prüfung, bei einem Fehler ist also noch nichts
  verändert.

#### Datumswerte und die Bedeutung von `expires`
`expires: 2027-01-31` ist für YAML ein Datumsobjekt, `"2027-01-31"` ein String. `to_datetime`
will Text und scheitert am Datumsobjekt mit `strptime() argument 1 must be str, not
_AnsibleTaggedDate`; `| string | to_datetime('%Y-%m-%d')` normalisiert also beides (gemessen mit
einem unquotierten Datum in einer `-e @Datei`). Ein anderes Format scheitert ebenfalls:
`'31.01.2027'` ergibt `time data '31.01.2027' does not match format '%Y-%m-%d'`.

Das Ergebnis ist Mitternacht am Tagesanfang, und `now()` ist die lokale Zeit des Control-Knotens.
Mit `> now()` ist `expires` deshalb der **erste Tag, an dem die Ausnahme nicht mehr gilt**; der
letzte Tag, an dem sie akzeptiert wird, ist der Vortag. Gemessen: gestern und heute werden
abgelehnt, morgen besteht. Der Check testet nur 2001 und 2099, er kann also zwei Regeln nicht
unterscheiden: schreib deine für alle auf, die Ausnahmen beantragen.

#### Vertragstests
Der Check sieht deine Dateien nie an. Er startet das Playbook mit
`ANSIBLE_STDOUT_CALLBACK=ansible.posix.json` und wertet aus, welche Tasks übersprungen wurden.
So testet man Infrastrukturcode von außen, und deshalb sind Task-Namen eine Schnittstelle: ein
umbenanntes `L2-modules | ...` bricht den Test, wie es jeden Nutzer brechen würde. `--check` macht
die fünf Läufe wiederholbar und harmlos.

### Stolperfallen und gemessene Fakten

| Symptom | Ursache | Lösung |
|---|---|---|
| `'>=' not supported between instances of '_AnsibleTaggedStr' and 'int'` | `-e cis_level=2` kommt als String an | `\| int` in jedem Vergleich; der Check übergibt Zahlen und fängt es nicht |
| `strptime() argument 1 must be str, not _AnsibleTaggedDate` | ein unquotiertes Datum ist in YAML ein Datumsobjekt | `\| string` vor `to_datetime`, oder das Datum quotieren |
| Eine gültig aussehende Ausnahme wird an ihrem Datum abgelehnt | `to_datetime` ist Mitternacht, `expires` ist der erste ungültige Tag | den Tag nach dem letzten gewollten Tag eintragen |
| Eine Ausnahme mit leerer Begründung wird akzeptiert | `length > 0` zählt das Leerzeichen mit | `\| trim` vor `\| length` |
| Ein `l2-*`-Task zählt bei Level 1 als gelaufen | ein Schleifen-Task bedient mehrere Kontrollen und sein `when` hängt von `item` ab | ein Block je Kontrolle, `when` am Block |
| Der Check ist grün, aber ungültige Eingaben werden erst nach den Kontrollen abgelehnt | der Check liest den Exit-Code, nicht die Reihenfolge | Validierung zuerst im Play |

### Praxis-Hinweise
- Ausnahmen in Git neben dem Inventar ablegen (`group_vars/<env>/cis_exceptions.yml`), nur über
  geprüfte Merge Requests ändern, Ticketnummer in `reason`. 5.01 wendet diesen Mechanismus auf alle
  Kontrollen an, und sein Bericht zählt die ausgenommenen Kontrollen und listet sie mit ihrer
  Begründung, damit Auditoren das ganze Bild sehen.
- Eine ablaufende Ausnahme lässt die Pipeline genau an diesem Tag scheitern. Eine Warnung einige
  Wochen vorher (siehe Bonus) gibt dem Verantwortlichen Zeit, sie zu verlängern oder zu beheben.

### Weiterführend
- Lektion [L11 - Profile, Ausnahmen und datengetriebene Rollen](../../../docs/lessons/L11-profiles-exceptions-and-data-driven-roles.de.md): die Konzepte vor dieser Übung, mit Demos und Selbsttest-Fragen.
- Übung [5.01 - Abschlussprojekt: CIS-Rolle mit Audit- und Enforce-Modus](../../stage5-capstone/5.01-capstone-cis-role/README.de.md): derselbe Mechanismus für alle Kontrollen, mit Bericht.

## Musterlösung

Anzeigen mit `lab solution 4.02`, anwenden mit `lab solve 4.02`.
