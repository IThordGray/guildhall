# Guildhall

Single-player, timer-based guild-management game for phones (portrait), built in Godot with GDScript.

This repo runs on Shipyard: for anything bigger than a one-line change, work as the manager
(`/shipyard`). Knowledge: [docs/knowledge/README.md](docs/knowledge/README.md).

Design intent lives in the human's spec, a Claude Doc:
https://claude.ai/artifact/7H5Ejhq2HogoMq71BMAXDF — read it with the Claude Docs tools, never
web-fetch it. Where the spec and `docs/knowledge/` disagree, ask; the knowledge base records what
was decided for the build.

## Commands

`godot` = the standard (non-.NET) Godot 4.7.1 editor, at
`%LOCALAPPDATA%/Programs/Godot/godot.exe` (on the user PATH; shells started earlier may lack it).

- Test: `godot --headless --path . --import && godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test -gexit`
  — the import is required: without it GUT runs no tests and still exits 0.
- Build (web): `godot --headless --export-release "Web" build/web/index.html`
- Build (Android): `godot --headless --export-debug "Android" build/android/guildhall.apk`
- Main branch: `main`. Every push to `main` runs CI and deploys the web build to
  https://ithordgray.github.io/guildhall/
