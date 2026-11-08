# Glossar

*[English](GLOSSARY.md)*

Kurze Erklärungen der Begriffe, die die Lektionen und Aufgaben verwenden, sortiert nach dem
englischen Begriff, wie er in Ansible, im Code und in den Handbuchseiten steht; wo die
Lektionen einen deutschen Begriff verwenden, steht er in Klammern dahinter. Jeder Eintrag
verweist auf den Abschnitt der Lektion, der ihn ausführlich erklärt. Im Lab öffnet
`lab lesson <n>` eine Lektion und `lab docs glossary` diese Seite.


## A

- **ad-hoc command** (Ad-hoc-Kommando) - `ansible <pattern> -m <modul> -a <argumente>`: ein Modul auf vielen Hosts, ohne Playbook. Gut, um den Ist-Zustand anzusehen. ([L00](lessons/L00-lab-and-ansible-basics.de.md#inventar-und-patterns))
- **AIDE** - Advanced Intrusion Detection Environment: speichert Prüfsummen und Attribute von Dateien in einer Datenbank (der Baseline) und meldet später, was davon abweicht. ([L09](lessons/L09-auditing-and-integrity.de.md#aide-baseline-prüfung-update))
- **allow and deny lists** (Allow- und Deny-Listen) - `cron.allow` / `cron.deny` und `at.allow` / `at.deny` entscheiden, wer `crontab` und `at` benutzen darf. Eine vorhandene Allow-Datei gewinnt; bestehende Jobs bleiben unberührt. ([L06](lessons/L06-job-schedulers.de.md#wer-planen-darf-allow--und-deny-listen))
- **`always` (tag)** - Besonderes Tag: der Task läuft auch, wenn `--tags` andere Tags auswählt. Nur `--skip-tags always` hält ihn an. ([L07](lessons/L07-roles-tags-project-structure.de.md#tags-auswählen-was-läuft))
- **`any_errors_fatal`** - Play-Schlüsselwort: ein Fehler auf einem Host beendet das Play für alle Hosts. ([L14](lessons/L14-production-rollout.de.md#fehlersemantik-wer-hält-an-wenn-etwas-scheitert))
- **`assert`** - `ansible.builtin.assert` schlägt fehl, wenn eine Bedingung falsch ist - das Werkzeug, um Eingaben vor der ersten Änderung zu prüfen. ([L11](lessons/L11-profiles-exceptions-and-data-driven-roles.de.md#ausnahmen-sind-datensätze-und-eingaben-werden-geprüft-bevor-etwas-läuft))
- **`async` / `poll` / `async_status`** - Einen Task im Hintergrund auf dem Target ausführen: `async` ist die maximale Laufzeit in Sekunden, `poll: 0` kehrt sofort zurück, `async_status` fragt das Ergebnis später ab. ([L09](lessons/L09-auditing-and-integrity.de.md#langlaufende-tasks-async-poll-und-async_status))
- **at** - Plant einen Job, der einmal zu einer bestimmten Zeit läuft (`atd` führt ihn aus). ([L06](lessons/L06-job-schedulers.de.md#woher-jobs-kommen-und-mit-wessen-rechten-sie-laufen))
- **attack surface** (Angriffsfläche) - Alles, was ein Angreifer erreichen oder missbrauchen kann. Härtung verkleinert sie in Schichten: installiert, laufend, beim Start aktiviert. ([L03](lessons/L03-base-hardening.de.md#angriffsfläche-in-schichten-installiert-laufend-aktiviert))
- **audit mode** (Audit-Modus) - Ein Lauf der Rolle, der nur prüft und berichtet und nichts ändert. Im Lab nutzt er dieselben Tasks wie der Enforce-Modus, als Trockenlauf. ([L10](lessons/L10-compliance-reporting.de.md#ein-codepfad-für-audit-und-enforce))
- **auditd** - Der Daemon, der die Datensätze des Audit-Subsystems im Kernel auf die Platte schreibt. Welche Ereignisse aufgezeichnet werden, legen Audit-Regeln fest; `augenrules` fügt die Dateien in `/etc/audit/rules.d/` zusammen und lädt sie. ([L09](lessons/L09-auditing-and-integrity.de.md#das-audit-subsystem-der-kernel-zeichnet-auf-der-daemon-speichert))
- **authselect** - Das Werkzeug der Red-Hat-Familie, das den PAM-Stack aus einem Profil schreibt. Handänderungen an den erzeugten Dateien werden überschrieben. ([L08](lessons/L08-accounts-and-pam.de.md#pam-typen-controls-und-wer-den-stack-schreibt))
- **Automated / Manual** - Bewertungsstatus einer CIS-Empfehlung: eine *Automated* kann ein Werkzeug prüfen und zählt im CIS-CAT-Score, eine *Manual* braucht einen Menschen. Vor November 2020: Scored / Not Scored. ([L01](lessons/L01-cis-benchmarks.de.md#aufbau-einer-empfehlung))

## B

- **batch** (Welle) - Eine Gruppe von Hosts in einem Rollout mit `serial`. Die nächste Welle beginnt, wenn die vorige fertig ist. ([L14](lessons/L14-production-rollout.de.md#wellen-wellenlisten-und-die-prüfung-nach-jeder-welle))
- **`become`** - Die Rechteausweitung von Ansible: der Task läuft auf dem Target als anderer Benutzer, standardmäßig als root (im Lab über sudo). ([L00](lessons/L00-lab-and-ansible-basics.de.md#das-lab-ein-control-node-acht-targets))
- **`blacklist` (modprobe)** - Sagt `modprobe`, die eigenen Aliasse eines Moduls zu ignorieren. Ein ausdrückliches Laden über den Namen stoppt es nicht; `install <modul> /bin/false` schon. ([L05](lessons/L05-kernel-modules-and-sysctl.de.md#kernelmodule-wer-sie-lädt-und-was-modprobed-stoppen-kann))
- **`block` / `rescue` / `always`** - Gruppiert Tasks. `rescue` läuft, wenn ein Task im Block scheitert, `always` läuft in jedem Fall - ein Weg zurück nach einer gescheiterten Änderung. ([L02](lessons/L02-safe-changes.de.md#ein-weg-zurück-das-risiko-ordnen))

## C

- **canary** - Die erste, kleine Welle eines Rollouts, auf Vielfalt ausgewählt. Ein Problem zeigt sich dort, bevor sich die ganze Flotte geändert hat. ([L14](lessons/L14-production-rollout.de.md#wellen-wellenlisten-und-die-prüfung-nach-jeder-welle))
- **capability flag** (Fähigkeits-Flag) - Ein Wert in den Plattformdaten, der sagt, was eine Plattform kann (`..._supported: false`). Tasks fragen nach der Fähigkeit, nicht nach dem Betriebssystem. ([L11](lessons/L11-profiles-exceptions-and-data-driven-roles.de.md#plattformdaten-und-fähigkeits-flags))
- **`changed` / `ok`** - Task-Ergebnisse: `changed` heißt, das Modul hat das System geändert, `ok`, dass es schon im beschriebenen Zustand war. Ein zweiter Lauf eines korrekten Playbooks meldet nur `ok`. ([L00](lessons/L00-lab-and-ansible-basics.de.md#idempotenz-den-zustand-beschreiben-nicht-die-schritte))
- **`changed_when` / `failed_when`** - Legen fest, wie Ansible ein Task-Ergebnis bewertet. `raw`, `command` und `shell` können nicht wissen, ob sie etwas geändert haben, also sagst du es ihnen. ([L00](lessons/L00-lab-and-ansible-basics.de.md#wie-ein-modul-läuft))
- **check mode** (Check-Modus) - `--check`: Module melden, was sie ändern würden, ohne es zu ändern. Manche können es nicht vorhersagen (`raw`, `command`) und werden übersprungen, außer mit `check_mode: false`. ([L02](lessons/L02-safe-changes.de.md#check-modus-was-er-vorhersagen-kann-und-was-nicht))
- **CIS Benchmark** - Ein Konfigurationsleitfaden für eine Plattform, im Konsensverfahren vom Center for Internet Security geschrieben, aus nummerierten Empfehlungen. ([L01](lessons/L01-cis-benchmarks.de.md#was-ein-cis-benchmark-ist))
- **CIS Controls** - Die priorisierte Liste von Schutzmaßnahmen des CIS für eine ganze Organisation (Version 8.1). Nicht dasselbe wie die Benchmarks, die einzelne Systeme konfigurieren. ([L01](lessons/L01-cis-benchmarks.de.md#was-ein-cis-benchmark-ist))
- **CIS-CAT** - Das Prüfwerkzeug des CIS: prüft ein System gegen einen Benchmark und berechnet einen Score. ([L01](lessons/L01-cis-benchmarks.de.md#was-ein-cis-benchmark-ist))
- **collection** - Die Einheit, in der Module, Plugins und Rollen ausgeliefert werden, zum Beispiel `ansible.posix` oder `community.general`. Ihr Name ist der erste Teil des FQCN. ([L05](lessons/L05-kernel-modules-and-sysctl.de.md#collections-woher-ansibleposixsysctl-kommt))
- **compliance report** (Compliance-Bericht) - Die Ergebnisse eines Audits pro Host, zu einem Dokument zusammengefasst (im Lab JSON und Markdown), das zeigt, welche Kontrolle wo besteht. ([L10](lessons/L10-compliance-reporting.de.md#von-den-ergebnissen-pro-host-zu-einem-bericht))
- **control (lab catalogue)** (Kontrolle) - Ein Eintrag in `cis/controls.yml`: ein CIS-Abschnitt, den das Lab automatisiert, mit Level, Plattformen und Aufgaben. ([L01](lessons/L01-cis-benchmarks.de.md#der-lab-katalog-controlsyml-und-metayml))
- **control node** (Control-Node) - Die Maschine, auf der Ansible läuft und von der es sich mit den Targets verbindet - im Lab der Container `control`. ([L00](lessons/L00-lab-and-ansible-basics.de.md#das-lab-ein-control-node-acht-targets))
- **cron** - Der Daemon, der wiederkehrende Jobs aus den Crontabs, `/etc/crontab`, `/etc/cron.d` und den periodischen Verzeichnissen ausführt. Dateien, deren Eigentümer oder Rechte er nicht akzeptiert, ignoriert er. ([L06](lessons/L06-job-schedulers.de.md#woher-jobs-kommen-und-mit-wessen-rechten-sie-laufen))
- **custom facts** - Dateien in `/etc/ansible/facts.d/*.fact` auf einem Target: statisches JSON oder INI, oder ein ausführbares Programm, das JSON ausgibt. Sie erscheinen unter `ansible_local`. ([L10](lessons/L10-compliance-reporting.de.md#custom-facts-hosts-die-sich-selbst-beschreiben))

## D

- **dead-man switch** (Totmannschalter) - Ein zeitgesteuerter Job, der eine riskante Änderung zurücknimmt, wenn du sie nicht rechtzeitig bestätigst. Kappt die Änderung deine Verbindung, repariert sich der Host selbst. ([L13](lessons/L13-host-firewall-nftables.de.md#eine-änderung-die-du-vielleicht-nicht-überlebst-der-totmannschalter))
- **`defaults/` and `vars/`** - Zwei Variablen-Verzeichnisse einer Rolle: `defaults/` hat den niedrigsten Rang und ist die Schnittstelle für Nutzer, `vars/` hat einen hohen Rang und hält interne Daten. ([L07](lessons/L07-roles-tags-project-structure.de.md#defaults-und-vars-eine-schnittstelle-und-interne-daten))
- **`delegate_to` / `run_once`** - `delegate_to` führt einen Task auf einem anderen Host aus (oft `localhost`, dem Control-Node), `run_once` nur für den ersten Host der Welle. ([L10](lessons/L10-compliance-reporting.de.md#von-den-ergebnissen-pro-host-zu-einem-bericht), [L14](lessons/L14-production-rollout.de.md#vorabprüfung-und-gate-prüfen-bevor-du-änderst))
- **diff mode** (Diff-Modus) - `--diff`: zeigt Änderungen an Dateien Zeile für Zeile. Mit `--check` ist es eine Vorschau der Änderung. ([L00](lessons/L00-lab-and-ansible-basics.de.md#idempotenz-den-zustand-beschreiben-nicht-die-schritte), [L02](lessons/L02-safe-changes.de.md#check-modus-was-er-vorhersagen-kann-und-was-nicht))
- **drop-in** - Eine Datei in einem `.d`-Verzeichnis, die die Hauptkonfiguration einbindet (`sshd_config.d`, `sudoers.d`, `sysctl.d`). Die Reihenfolge der Dateien entscheidet, welcher Wert gewinnt. ([L03](lessons/L03-base-hardening.de.md#sshd-mehrere-dateien-ein-effektiver-wert))

## E

- **enforce mode** (Enforce-Modus) - Der Lauf der Rolle, der die Targets in den beschriebenen Zustand bringt. Er teilt seinen Codepfad mit dem Audit-Modus. ([L10](lessons/L10-compliance-reporting.de.md#ein-codepfad-für-audit-und-enforce))
- **exception** (Ausnahme) - Eine dokumentierte Abweichung von einer Kontrolle: ein Datensatz mit Kontroll-ID, Begründung und Ablaufdatum, geprüft, bevor etwas läuft. ([L11](lessons/L11-profiles-exceptions-and-data-driven-roles.de.md#ausnahmen-sind-datensätze-und-eingaben-werden-geprüft-bevor-etwas-läuft))

## F

- **facts** - Daten, die Ansible über einen Host sammelt (Modul `setup`), zum Beispiel `ansible_facts.os_family`. Im Lab sind die Familien `Debian`, `RedHat`, `Suse`, `Alpine` und `Archlinux`. ([L00](lessons/L00-lab-and-ansible-basics.de.md#facts))
- **faillock** - PAM-Modul (`pam_faillock`), das ein Konto nach einer Anzahl fehlgeschlagener Anmeldungen sperrt; Einstellungen in `faillock.conf`, das Kommando `faillock` zeigt und löscht den Zähler. ([L08](lessons/L08-accounts-and-pam.de.md#zwei-module-im-stack-pwquality-und-faillock))
- **finding** (Befund) - Das Ergebnis einer Kontrolle auf einem Host, als Datensatz mit einem Status festgehalten - kein gescheiterter Task, der den Lauf anhält. ([L10](lessons/L10-compliance-reporting.de.md#befunde-sind-daten-keine-fehler))
- **`first_found`** - Lookup, das die erste vorhandene Datei aus einer Liste liefert - geschrieben vom spezifischsten Namen (Distribution) bis zu einem allgemeinen. ([L07](lessons/L07-roles-tags-project-structure.de.md#defaults-und-vars-eine-schnittstelle-und-interne-daten), [L11](lessons/L11-profiles-exceptions-and-data-driven-roles.de.md#plattformdaten-und-fähigkeits-flags))
- **FQCN** - Vollqualifizierter Collection-Name eines Moduls, etwa `ansible.builtin.copy`. Das Profil `production` von ansible-lint verlangt ihn. ([L05](lessons/L05-kernel-modules-and-sysctl.de.md#collections-woher-ansibleposixsysctl-kommt))

## G

- **Galaxy** - Die zentrale Sammelstelle von Ansible für Rollen und Collections. `ansible-galaxy install -r requirements.yml` installiert sie; pinne eine Version oder einen Commit. ([L14](lessons/L14-production-rollout.de.md#community-rollen-galaxy-git-und-was-du-liest-bevor-du-ausführst))
- **gate** - Eine Prüfung am Anfang eines Rollouts, die ohne ausdrückliche Bestätigung nicht weitermacht: eine Variable ohne Default und ein `assert`. ([L14](lessons/L14-production-rollout.de.md#vorabprüfung-und-gate-prüfen-bevor-du-änderst))
- **`group_vars` / `host_vars`** - Verzeichnisse neben dem Inventar oder dem Playbook; eine Datei mit dem Namen einer Gruppe oder eines Hosts setzt Variablen für sie. ([L04](lessons/L04-platform-differences-as-data.de.md#woher-variablen-kommen))

## H

- **handler** - Ein Task, der nur läuft, wenn ein geänderter Task ihn benachrichtigt (`notify`), einmal, am Ende des Plays oder bei `meta: flush_handlers`. ([L02](lessons/L02-safe-changes.de.md#handler-nur-handeln-wenn-sich-etwas-geändert-hat))
- **hook (netfilter)** - Eine Stelle im Paketweg des Kernels (`input`, `output`, `forward`, ...), an der eine nftables-Chain hängt. ([L13](lessons/L13-host-firewall-nftables.de.md#wer-regeln-schreibt-tabellen-hooks-und-deine-eigene-tabelle))
- **`hostvars`** - Die Variablen und Facts jedes Hosts im Inventar, lesbar von jedem Host aus - der Weg, aus vielen Hosts einen Bericht zu bauen. ([L00](lessons/L00-lab-and-ansible-basics.de.md#facts))

## I

- **idempotency** (Idempotenz) - Derselbe Playbook-Lauf ändert nichts mehr, sobald der Zustand erreicht ist. Du beschreibst den Zustand, nicht die Schritte. ([L00](lessons/L00-lab-and-ansible-basics.de.md#idempotenz-den-zustand-beschreiben-nicht-die-schritte))
- **immutable audit configuration** (Sperre) - `-e 2` als letzte Audit-Regel sperrt die Regeln bis zum nächsten Neustart; niemand kann sie ändern, auch root nicht. ([L09](lessons/L09-auditing-and-integrity.de.md#regeldateien-lade-reihenfolge-und-die-sperre))
- **`import_tasks` / `include_tasks`** - Statisches und dynamisches Einbinden: `import_tasks` wird beim Lesen des Playbooks aufgelöst, `include_tasks` zur Laufzeit (Dateiname aus einer Variablen, in einer Schleife). ([L07](lessons/L07-roles-tags-project-structure.de.md#import_tasks-und-include_tasks-statisch-und-dynamisch))
- **`include_vars`** - Lädt eine Variablendatei zur Laufzeit; ihre Werte haben einen hohen Rang. ([L07](lessons/L07-roles-tags-project-structure.de.md#defaults-und-vars-eine-schnittstelle-und-interne-daten), [L11](lessons/L11-profiles-exceptions-and-data-driven-roles.de.md#plattformdaten-und-fähigkeits-flags))
- **interpreter discovery** - Wie Ansible das Python auf einem Target wählt. Ein Host ohne Python (Alpine vor 0.02) ist nur mit `raw` erreichbar. ([L00](lessons/L00-lab-and-ansible-basics.de.md#wie-ein-modul-läuft))
- **inventory** (Inventar) - Die Liste der Hosts und Gruppen, mit denen Ansible arbeitet. Das Lab gruppiert seine acht Targets nach Familie (`debian_family`, `redhat_family`, ...). ([L00](lessons/L00-lab-and-ansible-basics.de.md#inventar-und-patterns))

## J

- **Jinja2** - Die Template-Sprache von Ansible: `{{ ausdruck }}`, Filter wie `| default(...)` und `{% ... %}`-Anweisungen. ([L04](lessons/L04-platform-differences-as-data.de.md#jinja2-in-ansible-ausdrücke-filter-undefinierte-werte))

## L

- **Level 1 / Level 2** - CIS-Profile: Level 1 ist die praxistaugliche Basis mit wenig Auswirkung, Level 2 ergänzt tiefere Verteidigung, die Funktion kosten kann. Das Lab wählt mit `cis_level`. ([L01](lessons/L01-cis-benchmarks.de.md#profile-und-levels), [L11](lessons/L11-profiles-exceptions-and-data-driven-roles.de.md#ein-profil-ist-ein-wert))
- **lint profile** (Lint-Profil) - Die Regelsätze von ansible-lint, jeder erweitert den vorigen: `min`, `basic`, `moderate`, `safety`, `shared`, `production`. ([L07](lessons/L07-roles-tags-project-structure.de.md#eine-rolle-linten))
- **`login.defs`** - Vorgaben der shadow-Werkzeuge für neue Konten: Passwort-Alterung (`PASS_MAX_DAYS`, ...) und Hash-Verfahren (`ENCRYPT_METHOD`). Bestehende Konten behalten ihre Werte. ([L08](lessons/L08-accounts-and-pam.de.md#alterung-hashing-und-woher-vorgaben-kommen))
- **loop** (Schleife) - `loop:` wiederholt einen Task für jedes Element einer Liste; `item` ist das aktuelle Element. ([L04](lessons/L04-platform-differences-as-data.de.md#schleifen-über-daten))

## M

- **management channel** (Verwaltungskanal) - Der Weg, über den du einen Host verwaltest - SSH und sudo. Ein Fehler dort sperrt dich aus, darum brauchen diese Änderungen die meiste Sorgfalt. ([L03](lessons/L03-base-hardening.de.md#sudo-drop-ins-reihenfolge-und-der-verwaltungskanal))
- **`max_fail_percentage`** - Play-Schlüsselwort: beendet den Lauf, wenn mehr als dieser Anteil der Hosts in der aktuellen Welle gescheitert ist. ([L14](lessons/L14-production-rollout.de.md#fehlersemantik-wer-hält-an-wenn-etwas-scheitert))
- **mode (file)** (Modus) - Die Rechte-Bits einer Datei. Schreib ihn als Zeichenkette in Anführungszeichen (`"0644"`): YAML liest `644` als Dezimalzahl. Ein CIS-Modus ist ein Maximum - strenger besteht. ([L03](lessons/L03-base-hardening.de.md#modi-bits-schreibweise-und-warum-compliance-eine-schranke-ist))
- **`modprobe.d`** - Konfigurationsverzeichnisse von `modprobe`. `install <modul> /bin/false` stoppt das Laden über den Namen; kmod liest die Dateien in Namensreihenfolge und nimmt die erste `install`-Zeile, die es findet. ([L05](lessons/L05-kernel-modules-and-sysctl.de.md#kernelmodule-wer-sie-lädt-und-was-modprobed-stoppen-kann))
- **module** (Modul) - Die Arbeitseinheit: Ansible kopiert es auf das Target und führt es mit Python aus (außer `raw`), es meldet `ok`, `changed` oder `failed`. ([L00](lessons/L00-lab-and-ansible-basics.de.md#wie-ein-modul-läuft))

## N

- **namespaced parameter** - Ein sysctl-Schlüssel mit einer Kopie pro Namespace (die meisten `net.*`-Schlüssel): ein Container kann seinen eigenen setzen. Ein globaler Schlüssel gehört dem Host-Kernel und wird geteilt. ([L05](lessons/L05-kernel-modules-and-sysctl.de.md#ein-kernel-viele-sichten-namespaced-und-globale-parameter))
- **nftables** - Der Linux-Paketfilter (`nft`): Tabellen enthalten Chains, Chains enthalten Regeln. Eine mit `nft -f` geladene Datei wird als eine Transaktion angewandt - alles oder nichts. ([L13](lessons/L13-host-firewall-nftables.de.md#wer-regeln-schreibt-tabellen-hooks-und-deine-eigene-tabelle))
- **`no_log`** - Verbirgt die Argumente und das Ergebnis eines Tasks in der Ausgabe. Ein Geheimnis, das ein Template in eine Datei schreibt, hält es nicht auf. ([L12](lessons/L12-secrets-with-ansible-vault.de.md#no_log-was-es-verbirgt-und-was-nicht))

## P

- **PAM** - Pluggable Authentication Modules: pro Dienst ein Stack von Modulen mit Typ (`auth`, `account`, `password`, `session`) und Control (`required`, `sufficient`, ...). ([L08](lessons/L08-accounts-and-pam.de.md#pam-typen-controls-und-wer-den-stack-schreibt))
- **pattern** - Ein Ausdruck, der Hosts aus dem Inventar auswählt: `targets:!alpine_family` (alle außer einer Gruppe), `debian_family:redhat_family` (Vereinigung). ([L00](lessons/L00-lab-and-ansible-basics.de.md#inventar-und-patterns))
- **platform data** (Plattformdaten) - Werte, die sich je Plattform unterscheiden (Paketnamen, Pfade, Gruppen), in Datendateien statt in einem `when` an jedem Task. ([L04](lessons/L04-platform-differences-as-data.de.md#ein-task-viele-plattformen-daten-statt-bedingungen), [L11](lessons/L11-profiles-exceptions-and-data-driven-roles.de.md#plattformdaten-und-fähigkeits-flags))
- **preflight** (Vorabprüfung) - Das erste Play eines Rollouts: es prüft nur, was die Änderung braucht, und scheitert, bevor sich etwas geändert hat. ([L14](lessons/L14-production-rollout.de.md#vorabprüfung-und-gate-prüfen-bevor-du-änderst))
- **profile (CIS)** (Profil) - Eine Auswahl von Empfehlungen für einen Zweck: Level (1 oder 2) und Art des Systems (Server oder Workstation). In einer Rolle ist ein Profil einfach ein Wert. ([L01](lessons/L01-cis-benchmarks.de.md#profile-und-levels), [L11](lessons/L11-profiles-exceptions-and-data-driven-roles.de.md#ein-profil-ist-ein-wert))
- **pwquality** - PAM-Modul (`pam_pwquality`), das ein neues Passwort gegen Regeln wie Mindestlänge und Zeichenklassen prüft; Einstellungen in `pwquality.conf`. ([L08](lessons/L08-accounts-and-pam.de.md#zwei-module-im-stack-pwquality-und-faillock))

## R

- **`raw`** - Modul, das ein Kommando über SSH ohne Python auf dem Target schickt - für den Bootstrap. Es kann nicht sagen, ob es etwas geändert hat, und wird im Check-Modus übersprungen. ([L00](lessons/L00-lab-and-ansible-basics.de.md#wie-ein-modul-läuft))
- **recommendation (CIS)** (Empfehlung) - Ein nummerierter Eintrag eines Benchmarks mit Profil, Bewertungsstatus, Beschreibung, Begründung, Audit und Abhilfe. Nummern können sich zwischen Benchmark-Versionen verschieben. ([L01](lessons/L01-cis-benchmarks.de.md#aufbau-einer-empfehlung))
- **`register`** - Speichert das Ergebnis eines Tasks in einer Variablen, die spätere Tasks nutzen, zum Beispiel in einem `when`. ([L02](lessons/L02-safe-changes.de.md#bedingungen-überspringen-was-nicht-zutrifft))
- **`requires` (meta.yml)** - Lab: die Aufgaben, auf deren Zielzustand eine Aufgabe aufbaut. `lab start` warnt, wenn du sie noch nicht bestanden hast. ([L01](lessons/L01-cis-benchmarks.de.md#der-lab-katalog-controlsyml-und-metayml))
- **reset (lab)** - `./lab.sh reset <host|all>` auf dem Host erzeugt Targets im ursprünglichen, nicht konformen Zustand neu. ([L00](lessons/L00-lab-and-ansible-basics.de.md#das-lab-ein-control-node-acht-targets))
- **role** (Rolle) - Ein Verzeichnis mit festem Aufbau (`tasks/`, `handlers/`, `defaults/`, `vars/`, `templates/`, `files/`, `meta/`), das ein Play als eine Einheit nutzt. ([L07](lessons/L07-roles-tags-project-structure.de.md#eine-rolle-ist-ein-verzeichnis-mit-einem-vertrag))

## S

- **salt** - Ein Zufallswert, der in einen Passwort-Hash eingeht, damit gleiche Passwörter verschiedene Hashes ergeben. Ein fester Salt macht `password_hash` idempotent. ([L12](lessons/L12-secrets-with-ansible-vault.de.md#ein-passwort-hashen-salt-und-idempotenz))
- **`serial`** - Play-Schlüsselwort: führt das Play in Wellen aus - eine Zahl, ein Prozentsatz oder eine Liste wie `[1, "50%", "100%"]`. ([L14](lessons/L14-production-rollout.de.md#wellen-wellenlisten-und-die-prüfung-nach-jeder-welle))
- **shadow** - `/etc/shadow` enthält die Passwort-Hashes und die Alterungsfelder der Konten; normale Benutzer dürfen sie nicht lesen. Der Hash beginnt mit `$id$`, das das Verfahren nennt. ([L08](lessons/L08-accounts-and-pam.de.md#konten-datenbanken-passwd-shadow-und-was-das-passwortfeld-sagt))
- **sshd effective value** (effektiver Wert) - sshd liest Hauptdatei und Drop-ins der Reihe nach und nimmt für fast jedes Schlüsselwort den ersten Wert. `sshd -T` zeigt, was gilt. ([L03](lessons/L03-base-hardening.de.md#sshd-mehrere-dateien-ein-effektiver-wert))
- **sudoers** - Die sudo-Konfiguration (`/etc/sudoers` und `sudoers.d`). Eine kaputte Datei kann dich root kosten, darum wird eine neue geprüft, bevor sie gilt (`validate`). ([L03](lessons/L03-base-hardening.de.md#sudo-drop-ins-reihenfolge-und-der-verwaltungskanal))
- **sysctl** - Kernel-Parameter unter `/proc/sys`. Es zählt der laufende Wert; Dateien in den `sysctl.d`-Verzeichnissen setzen ihn beim Start, in der Reihenfolge ihrer Namen. ([L05](lessons/L05-kernel-modules-and-sysctl.de.md#sysctl-laufender-wert-datei-und-die-reihenfolge-der-dateien))
- **systemd timer** (systemd-Timer) - Eine Unit, die einen Dienst nach Zeitplan startet - einer der Orte, an denen Jobs außerhalb von cron laufen. ([L06](lessons/L06-job-schedulers.de.md#weitere-orte-an-denen-sich-jobs-verstecken))

## T

- **tag** - Eine Markierung an Tasks, Blöcken oder Rollen; `--tags` und `--skip-tags` wählen, was läuft. `always` und `never` sind besonders. ([L07](lessons/L07-roles-tags-project-structure.de.md#tags-auswählen-was-läuft))
- **target** - Ein Host, den Ansible verwaltet (Managed Node). Das Lab hat acht: debian, ubuntu, rocky, alma, fedora, opensuse, arch, alpine. ([L00](lessons/L00-lab-and-ansible-basics.de.md#das-lab-ein-control-node-acht-targets))
- **template** - `ansible.builtin.template` rendert eine Jinja2-Datei mit den Variablen des Hosts und schreibt das Ergebnis auf das Target. ([L04](lessons/L04-platform-differences-as-data.de.md#templates-dateien-aus-variablen))
- **`TMOUT`** - Shell-Variable: eine untätige interaktive Shell endet nach so vielen Sekunden. Gesetzt in einem Profil-Skript, darum sieht ein nicht interaktiver Ansible-Task sie nicht. ([L08](lessons/L08-accounts-and-pam.de.md#login-shells-wo-umask-und-tmout-wohnen))

## U

- **`umask`** - Die Maske, die neuen Dateien Rechte-Bits wegnimmt. Login-Shells setzen sie in ihren Profil-Skripten. ([L08](lessons/L08-accounts-and-pam.de.md#login-shells-wo-umask-und-tmout-wohnen))

## V

- **`validate`** - Parameter von `copy`, `template` und anderen: ein Kommando, das die neue Datei (`%s`) prüft, bevor sie die alte ersetzt. ([L02](lessons/L02-safe-changes.de.md#validate-die-datei-testen-bevor-sie-existiert))
- **variable precedence** (Variablen-Rangfolge) - Die Regeln, welche von mehreren Definitionen einer Variablen gewinnt: `-e` schlägt alles, Rollen-Defaults verlieren gegen jede andere Variable. ([L04](lessons/L04-platform-differences-as-data.de.md#woher-variablen-kommen))
- **Vault** - Ansible Vault verschlüsselt Dateien oder einzelne Werte mit einem Passwort; Vault-IDs unterscheiden mehrere Passwörter. ([L12](lessons/L12-secrets-with-ansible-vault.de.md#vault-dateien-passwörter-ids))

## W

- **`wait_for_connection`** - Wartet, bis ein Host wieder antwortet - nach einer Änderung, die die Verbindung unterbrochen haben kann. ([L13](lessons/L13-host-firewall-nftables.de.md#eine-änderung-die-du-vielleicht-nicht-überlebst-der-totmannschalter))
- **`when`** - Eine Bedingung an einem Task; ist sie falsch, wird der Task übersprungen. An einem Task mit Schleife wird sie pro Element ausgewertet. ([L02](lessons/L02-safe-changes.de.md#bedingungen-überspringen-was-nicht-zutrifft))
