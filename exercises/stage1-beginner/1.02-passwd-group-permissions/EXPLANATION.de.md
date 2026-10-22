# 1.02 - Rechte auf /etc/passwd und /etc/group: Erklärung

### Lösung
```yaml
- name: Fix account file permissions
  hosts: targets
  become: true
  tasks:
    - name: /etc/passwd is 0644 root:root
      ansible.builtin.file:
        path: /etc/passwd
        owner: root
        group: root
        mode: "0644"
    - name: /etc/group is 0644 root:root
      ansible.builtin.file:
        path: /etc/group
        owner: root
        group: root
        mode: "0644"
```

### Die Oktal-Falle (Bonus)
| Du schreibst | YAML sieht | Ergebnis |
|---|---|---|
| `mode: "0644"` | String | `rw-r--r--` ✔ |
| `mode: 0644` | Oktal-Int (YAML 1.1) | geht, aber ansible-lint warnt |
| `mode: 644` | **dezimal** 644 = oktal 1204 | `-w----r-T` ✘ |
`ansible-lint` hat genau dafür die Regel `risky-octal`.

### Symbolische Modi
`mode: "u=rw,go=r"` ist gleichwertig und selbsterklärend. Symbolische Modi können auch
Bits *entfernen*, ohne andere anzufassen (`go-w`) - praktisch für "höchstens
0644"-Anforderungen, dann hängt das Ergebnis aber vom Ausgangszustand ab.

### `state: touch` wäre falsch
`touch` aktualisiert bei jedem Lauf die Zeitstempel → nie idempotent, und es würde
fehlende Dateien anlegen. Für die Bonus-Sicherungsdateien nutze `stat` + `when`
(Stufe 2).

## Musterlösung

Anzeigen mit `lab solution 1.02`, anwenden mit `lab solve 1.02`.
