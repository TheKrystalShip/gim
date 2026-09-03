# CLAUDE.md

## Project Overview

GIM (Godot Install Manager) is a bash script that manages and launches multiple Godot engine versions on Linux. It uses [Argbash](https://github.com/matejak/argbash) for CLI argument parsing.

## Key Files

- `gim.m4` — Argbash M4 template (source of truth for arg parsing and app logic)
- `gim.sh` — Generated output script (do not edit directly; regenerate from gim.m4)
- `args.md` — CLI argument reference documentation
- `old/` — Archived earlier versions (not active code)

## Dependencies

- `curl` or `wget` — for downloading Godot releases
- `unzip` — for extracting downloaded archives
- `jq` — for parsing GitHub API responses

## Build/Regenerate

After editing `gim.m4`, regenerate `gim.sh`:

```bash
argbash gim.m4 -o gim.sh
```

## Directory Structure (Runtime)

| Path | Purpose |
|------|---------|
| `~/.config/gim/` | Config directory (XDG_CONFIG_HOME) |
| `~/.local/share/gim/editors/` | Installed Godot editor binaries (XDG_DATA_HOME) |

## Conventions

- All edits go in `gim.m4`, never edit `gim.sh` directly
- Follow existing code style (2-space indent, LF line endings per .editorconfig)
- XDG Base Directory spec compliance for all paths
