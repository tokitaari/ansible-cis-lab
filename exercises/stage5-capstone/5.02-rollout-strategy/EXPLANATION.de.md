# 5.02 - Rollout-Strategie: Vorabprüfung, Canary, Wellen: Erklärung

### Warum es jedes Teil gibt
- **Vorabprüfung mit `any_errors_fatal`**: ist ein Host schon vor dem Start kaputt, soll
  ein Mensch draufschauen - keine halb ausgerollte Flotte.
- **Bestätigungsvariable**: Härtung ändert Authentifizierung und Netzwerkregeln. Ein
  Pflicht-`-e cis_rollout_confirm=true` verhindert "ich wollte nur den Check-Modus"-Unfälle
  und steht in den Joblogs.
- **Canary**: ein Host pro wichtiger Plattform fängt plattformspezifische Fehler früh.
- **`serial` + `max_fail_percentage: 0`**: ein Fehler in Welle 1 stoppt Welle 2. Ohne
  `max_fail_percentage` würde Ansible fröhlich mit der nächsten Welle weitermachen.
- **Nachprüfung mit neuer Verbindung**: der bestehende SSH-Master überlebt viele Fehler;
  nur ein *frischer* Login beweist, dass der nächste Operator noch hineinkommt.

### Freier Platz: was ein Host über sich wissen kann
`ansible_facts.mounts` wirkt wie die naheliegende Quelle, aber die Facts lassen jeden Mount
weg, dessen Device nicht mit `/` beginnt - den `overlay`-Root eines Containers, `tmpfs`,
viele Netzwerk-Dateisysteme. Im Lab gibt es schlicht keinen Eintrag für `/`, und ein
`default(0)` macht daraus "0 MB frei" auf jedem Host. `df -Pk /` fragt stattdessen den Kernel
und funktioniert überall (`-P` ist POSIX, auch busybox; `-k` legt die Einheit fest):
```yaml
- ansible.builtin.command: df -Pk /
  register: cis_df_root
  changed_when: false
  check_mode: false
- ansible.builtin.assert:
    that: (cis_df_root.stdout_lines[-1].split()[3] | int) * 1024 >= 209715200
```
Selbst die richtige Zahl kann täuschen: Bei **Thin Provisioning** sieht ein Host den freien
Platz seiner *virtuellen* Platte, nicht den des Speichers dahinter. Im Lab melden die Targets
die Kapazität der WSL2-/Docker-Desktop-VHDX (bis 1 TB), während auf dem Windows-Laufwerk, das
sie enthält, vielleicht nur noch wenige GB frei sind; dasselbe gilt für qcow2-Images,
Thin-LVM-Pools, VMware-Thin-Disks und SAN-LUNs. Eine Vorabprüfung im Host kann das nicht
sehen - die Kapazität des darunterliegenden Speichers gehört ins Monitoring der Plattform.

### Trockenläufe
`--check` führt die Vorabprüfung trotzdem aus (lesende Befehle mit `check_mode: false`) -
du kannst die Sperrlogik also testen, ohne Hosts anzufassen.

### Wellengrößen
`serial: [1, "30%", "100%"]` heißt 1 Host, dann 30 % der übrigen, dann der Rest. Für
2.000 Server vielleicht `[1, 10, "5%", "25%", "100%"]` - die Idee: erst Vertrauen
aufbauen, dann den Schadensradius vergrößern.

## Musterlösung

Anzeigen mit `lab solution 5.02`, anwenden mit `lab solve 5.02`.
