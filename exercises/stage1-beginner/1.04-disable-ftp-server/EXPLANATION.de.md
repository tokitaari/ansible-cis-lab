# 1.04 - FTP-Server stoppen und deaktivieren: Erklärung

### Was der Check prüft
`lab check 1.04` führt `check.yml` auf `targets` aus: Er sammelt `service_facts`, nimmt den
Eintrag `vsftpd` (`vsftpd.service` bei systemd, `vsftpd` bei OpenRC) und prüft, dass der Zustand
weder `running` noch `started` ist und der Dienst nicht aktiviert ist. systemd- und SysV-Hosts
melden `status: enabled`; OpenRC (Alpine) meldet die Runlevels, `default` bedeutet aktiviert.
Danach läuft dein Playbook noch einmal mit `--check` und muss `changed=0` melden.

Der Check prüft nur das Ergebnis:

- Ein Host ohne `vsftpd`-Eintrag besteht ("not present"). Das Entfernen des Pakets besteht
  also, ebenso eine maskierte Unit.
- Anforderung 3 prüft er nicht: Eine Lösung ohne `package_facts` und `when` besteht auf allen acht
  Lab-Hosts, weil alle `vsftpd` haben.

### So funktioniert es

#### Ein Modul, zwei Init-Systeme
`service` liest den Fact `service_mgr`. Bei systemd übergibt es an das Modul `systemd`, sonst an
das Legacy-Service-Modul, das auch OpenRC bedient (`rc-service`, `rc-update`). Gemessen:
derselbe Task läuft auf allen acht Hosts; der zweite Lauf ist überall `changed=0`. Für
Funktionen nur für systemd (`masked`, `daemon_reload`) nimm `ansible.builtin.systemd_service`.

#### `package_facts` und `when`, nicht `ignore_errors`
`package_facts` füllt `ansible_facts.packages`, ein Dict mit dem Paketnamen als Schlüssel. Die
Bedingung `'vsftpd' in ansible_facts.packages` überspringt den Task auf Hosts ohne das Paket.
`ignore_errors` würde jeden Fehler verstecken, auch einen Tippfehler im Dienstnamen.

Ein fehlender Dienst scheitert nicht überall. Gemessen nach dem Entfernen von `vsftpd`, mit dem
`service`-Task noch auf den alten Facts: Er scheiterte auf rocky, alma, fedora, opensuse und arch
mit `Could not find the requested service vsftpd: host`, meldete auf debian und ubuntu aber `ok`.
Auf alpine meldete das `service`-Modul `SUCCESS` für einen Namen, den es nicht gibt. Warum Debian
und Ubuntu abweichen, wurde nicht untersucht. Eine Bedingung, die auf allen Familien funktioniert,
ist die sichere Wahl.

#### Deaktivieren, maskieren, entfernen
Gemessen auf den sieben systemd-Hosts:

- `enabled: false` ergibt `is-enabled=disabled`, `is-active=inactive`. `systemctl start vsftpd`
  funktioniert trotzdem (rc=0), danach ist der Dienst `active`.
- `systemctl mask` verlinkt die Unit auf `/dev/null` (`/etc/systemd/system/vsftpd.service`);
  `is-enabled=masked`, und ein Start scheitert mit `Unit vsftpd.service is masked.` (rc=1).
  `service_facts` meldet dann `status: masked`.
- Das Entfernen des Pakets entfernt das Programm. CIS bevorzugt das; Stoppen/Maskieren ist der
  Ausweg, wenn ein anderes Paket es braucht.

#### Reihenfolge (Bonus)
Facts sind eine Momentaufnahme. Entfernst du das Paket zuerst und stoppst danach den Dienst mit
dem alten `package_facts`-Ergebnis, ist das `when` weiterhin wahr. Gemessen: 5 von 7
systemd-Hosts scheitern wie oben gezeigt. Mit einem zweiten `package_facts`-Aufruf nach dem
Entfernen wird der Task übersprungen (`lab check` zeigt dann `skipped=1` auf rocky und ubuntu).
Auf alpine endete derselbe Reihenfolge-Versuch mit `ok` für den Stopp-Task.

### Hinweise je Familie
| Host | Init | Zustand beim Lab-Start |
|---|---|---|
| debian, ubuntu | systemd | `vsftpd` aktiviert und aktiv |
| rocky, alma, fedora, opensuse, arch | systemd | `vsftpd.service` aktiviert und aktiv |
| alpine | OpenRC | `status: started`, Runlevel `default` |

In `service_facts` auf alpine lautet der Eintrag nach der Lösung `name: vsftpd`, `source: openrc`,
`state: stopped`, `runlevels: null`.

### Stolperfallen und gemessene Fakten
| Symptom | Ursache | Behebung |
|---|---|---|
| `Could not find the requested service vsftpd: host` | Paket entfernt, alte Facts | mit `package_facts` auffrischen oder Reihenfolge ändern |
| Dienst startet von Hand wieder | `enabled: false` ist nicht `masked` | `masked: true` mit `systemd_service` (nur systemd) |
| Alpine scheitert, kein Python | `0.02` nicht angewendet | zuerst Übung 0.02 ausführen |

### Praxis-Hinweise
- Das Lab hat überall `vsftpd`, der Skip-Zweig läuft auf einem frischen Lab also nie. In einer
  gemischten Flotte zählt er.
- Der Check akzeptiert entferntes Paket, maskierte Unit und gestoppten Dienst gleichermaßen;
  wähle, was deine Vorgabe verlangt.

### Weiterführend
- Lektion [L02 - Sichere Änderungen](../../../docs/lessons/L02-safe-changes.de.md): Bedingungen und `--check`.
- Lektion [L03 - Basis-Härtung](../../../docs/lessons/L03-base-hardening.de.md): Pakete, Dienste, Dateien, SSH und sudo an einem Ort.
- Übung [1.01 - Unsichere Client-Pakete entfernen](../1.01-remove-telnet/README.de.md): `package` und `package_facts`.

## Musterlösung

Anzeigen mit `lab solution 1.04`, anwenden mit `lab solve 1.04`.
