# CLAUDE.md

## Project Overview

GIM (Godot Install Manager) is a bash script that manages and launches multiple Godot engine versions on Linux. It uses [Argbash](https://github.com/matejak/argbash) for CLI argument parsing.

## Key Files

- `gim.m4` — Argbash M4 template (source of truth for arg parsing and app logic)
- `gim.sh` — Generated output script (do not edit directly; regenerate from gim.m4)
- `args.md` — CLI argument reference documentation
- `old/` — Archived earlier versions (not active code)

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
| `~/.config/gim/default_editor` | Default editor version (unused currently) |

## Planned Changes

### Part 1: Clean Up gim.m4

1. Remove dead `$_arg_list` dispatch block (lines 86-101) — argbash handles `--list` directly
2. Fix `_arg_run` default from `"run_default_editor"` to `""`
3. Remove unused `DEFAULT_EDITOR_FILE` constant
4. Remove commented-out `# echo "Installed editors:"`
5. Update `--run` help text to match args.md

### Part 2: Add `--delete <version>`

- Add `ARG_OPTIONAL_SINGLE([delete], d, ...)` to argbash template
- Add `delete_editor()` function with y/N confirmation prompt
- Use existing `find_editor_by_version` to locate binary before deletion

### Part 3: Implement `--run` Handler

- Add `run_editor()` function
- Empty version → run latest installed editor
- Specific version → find and run that version
- Launch editor in background with `&`

### Part 4: Implement `--install <version>`

- Download from: `https://github.com/godotengine/godot-builds/releases`
- URL pattern: `.../download/{version}-stable/Godot_v{version}-stable_linux.x86_64.zip`
- Dependencies: `curl` or `wget`, `unzip`
- `install_editor()` function: download, extract, move to editors dir, chmod +x

### Part 5: Regenerate gim.sh

- Run `argbash gim.m4 -o gim.sh` after all changes

## Conventions

- All edits go in `gim.m4`, never edit `gim.sh` directly
- Follow existing code style (2-space indent, LF line endings per .editorconfig)
- XDG Base Directory spec compliance for all paths
