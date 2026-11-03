# skills
ausgewählte Skills

| Skill | Beschreibung | Quelle |
|-------|--------------|--------|
| [**dependency-track**](skills/dependency-track/) | Dependency-Track (SCA): Projekte, Findings, CVE-Audits, Policy-Violations, SBOM-Upload | [rezkam/boring-but-good](https://github.com/rezkam/boring-but-good) (Apache-2.0), gehärtet |

## Installation in Claude Code (Code-Tab der Desktop-App oder CLI)

Das Repo ist ein Plugin-Marketplace. Einmal hinzufügen, dann Skills einzeln installieren:

```
/plugin marketplace add DannySotzny/skills
/plugin install dependency-track@dannysotzny-skills
```

In der Desktop-App geht das auch über die Plugin-Verwaltung: Marketplace `DannySotzny/skills` hinzufügen, Plugin `dependency-track` installieren.
Updates: `/plugin marketplace update dannysotzny-skills`.

Alternativ von Hand: den Ordner `skills/dependency-track` nach `~/.claude/skills/dependency-track` kopieren.

## Erste Nutzung von dependency-track

Einfach fragen, z. B. „Welche kritischen Findings hat Projekt X in Dependency-Track?“. Claude prüft die Konfiguration, fragt nach der Server-URL und nennt dir den Befehl, mit dem du den API-Key **selbst im Terminal** hinterlegst (versteckte Eingabe, der Key landet nie im Chat).

Voraussetzung: `jq` (Windows: `winget install jqlang.jq`, danach Claude neu starten). `curl`, `base64` und Bash bringt Git for Windows mit.

**Windows:** Den API-Key hinterlegst du in PowerShell oder cmd mit dem Starter `dtrack-setup.cmd` (ruft Git Bash auf). Den genauen Pfad nennt dir Claude bzw. Codex; bei einer Codex-Installation z. B.:

```powershell
& "$env:USERPROFILE\.codex\plugins\cache\dannysotzny-skills\dependency-track\1.1.1\skills\dependency-track\scripts\dtrack-setup.cmd"
```

**Codex:** Marketplace mit leerem Feld „Sparse-Pfade“ hinzufügen (`codex plugin marketplace add DannySotzny/skills`), dann `codex plugin add dependency-track@dannysotzny-skills`.

> Nur für Claude Code geeignet. Im normalen Chat / Cowork laufen Skills in einer Cloud-Sandbox, die deinen Dependency-Track-Server in der Regel nicht erreicht.
