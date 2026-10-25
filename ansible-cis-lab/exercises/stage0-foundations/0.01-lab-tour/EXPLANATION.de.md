# 0.01 - Rundgang: Inventar und Erreichbarkeit: Erklärung

### Was passiert ist
`ping` ist kein ICMP, sondern ein echtes Ansible-Modul: Ansible kopiert ein kleines
Python-Programm auf das Ziel, führt es aus und erwartet JSON zurück. Das geht nur, wo
Python vorhanden ist. Sieben Targets haben es, **Alpine nicht** - mit Absicht.
Minimale Images (Container, Appliances, Netzwerkgeräte) haben oft kein Python.

### Aufbau des Inventars
```
targets
├── debian_family:  debian, ubuntu
├── redhat_family:  rocky, alma, fedora
├── suse_family:    opensuse
├── arch_family:    arch
└── alpine_family:  alpine
```
Die Gruppierung nach OS-Familie ist Absicht: Paketnamen, Dienstnamen, Dateipfade und
Defaults unterscheiden sich genau entlang dieser Linien. Mit `group_vars/<gruppe>.yml`
hängst du später Daten an jede Familie.

### Nützliche Muster
- `ansible 'targets:!alpine_family' -m ansible.builtin.ping` - alle außer einer Gruppe
- `ansible 'redhat_family:&targets' ...` - Schnittmenge
- `ansible-inventory --host debian` zeigt die *zusammengeführten* Variablen eines Hosts -
  der erste Debug-Schritt, wenn "eine Variable den falschen Wert hat".

### Praxis
In Produktion kommen `ansible_host`, Jump-Hosts (`ansible_ssh_common_args`) und
dynamische Inventare (Azure, AWS, Satellite) dazu. Die Fragen bleiben dieselben.

## Musterlösung

Anzeigen mit `lab solution 0.01`, anwenden mit `lab solve 0.01`.
