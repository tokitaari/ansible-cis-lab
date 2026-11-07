# 2.06 - Alle Login-Banner aus einem Template

## Hinweis 1

`ansible.builtin.template` mit `src: banner.j2` und `dest: "{{ item }}"`.

## Hinweis 2

Das Template ist reiner Text mit `{{ lab_org_name }}` - hier keine `ansible_managed`-Zeile, Benutzer sehen diesen Text! Verwende gar keine getty-Escapes: der Check erkennt nur `\m \r \s \v`, aber `\S` oder `\n` verraten das System genauso.

## Hinweis 3

Der Task als Gerüst - füll jedes `"..."` aus. `templates/banner.j2` besteht aus zwei schlichten Zeilen: dem Namen der Organisation mit "authorized access only" und der Warnung zur Überwachung.

```yaml
- name: Deploy login banners
  ansible.builtin.template:
    src: "..."                        # ein Template für alle drei Dateien
    dest: "..."                       # das Loop-Item
    owner: root
    group: root
    mode: "0644"
  loop: "..."                         # /etc/motd, /etc/issue, /etc/issue.net
```

Referenz: `lab solution 2.06`.
