# 1.04 - FTP-Server stoppen und deaktivieren: Erklärung

### Lösung
```yaml
- name: Disable the FTP server
  hosts: targets
  become: true
  tasks:
    - name: Collect package facts
      ansible.builtin.package_facts:
    - name: Stop and disable vsftpd
      ansible.builtin.service:
        name: vsftpd
        state: stopped
        enabled: false
      when: "'vsftpd' in ansible_facts.packages"
```

### Ein Modul, zwei Init-Systeme
`service` erkennt `service_mgr` (Fact) und spricht mit systemd (`systemctl`) oder
OpenRC (`rc-service`/`rc-update`). Für reine systemd-Funktionen (`masked`,
`daemon_reload`) nimm `ansible.builtin.systemd_service`.

### Warum `package_facts` und nicht `ignore_errors: true`
`ignore_errors` versteckt *jeden* Fehler - auch den, der dich interessiert (Tippfehler
im Dienstnamen, Rechteproblem). Eine präzise Bedingung dokumentiert die Absicht.

### disable vs. mask vs. entfernen
- `enabled: false` - startet nicht beim Booten, kann aber von allem gestartet werden.
- `masked: true` - auf `/dev/null` gelinkt, lässt sich gar nicht starten (systemd).
- Paket entfernen - das Binary ist weg. Das empfiehlt CIS; stoppen/maskieren ist der
  Ausweg, wenn eine Abhängigkeit das Paket braucht.

### Reihenfolge (Bonus)
Entfernst du zuerst das Paket, ist auch die Service-Unit weg und der Stopp-Task würde
scheitern - es sei denn, dein `when` sieht noch die *alten* Paket-Facts (vor dem
Entfernen gesammelt). Facts sind eine Momentaufnahme; aktualisiere sie mit einem
weiteren `package_facts`-Aufruf, wenn die Reihenfolge zählt.

## Musterlösung

Anzeigen mit `lab solution 1.04`, anwenden mit `lab solve 1.04`.
