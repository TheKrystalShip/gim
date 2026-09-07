# Plan: Improve help output to match CLI conventions

## Motivation

GIM's current help output doesn't follow common CLI conventions used by popular tools like git, curl, jq, and ls. This makes the help less readable and familiar to users.

## Current help output

```
GIM - Godot Install Manager
Manage multiple Godot editor versions.
Usage: /home/devcas/repos/gim/gim.sh [-h|--help] [-v|--version] [-l|--list] ...
	-h, --help: Prints help
	-v, --version: Prints version
	-l, --list: list installed Godot editor versions
	-r, --run [VERSION]: run a specific installed Godot editor version; if omitted, run latest
	-i, --install VERSION: install a specific Godot editor version; use --list --online to see available versions
	-d, --delete VERSION: delete a specific installed Godot editor
	-m, --mono: download mono build instead of standard build; only works with --install
	-e, --experimental: include experimental versions in online listing; only works with --online
	-o, --online: list latest online editor versions; only works with --list
```

## Issues

| Issue | Current | Convention |
|-------|---------|------------|
| Usage line | Full script path | Command name only |
| Option separator | `:` after flags | Spaces/tabs |
| Alignment | Tab, no column alignment | Consistent column |
| Grouping | All options flat | Grouped by category |
| Capitalization | Mixed ("Prints" vs "list") | Consistent lowercase |
| Required args | `UPPERCASE` | `<angle brackets>` |
| Examples | None | Common usage examples |

## Proposed new format

```
GIM - Godot Install Manager
Manage multiple Godot editor versions.

Usage: gim [OPTIONS]

Options:
  -h, --help                        Show this help message
  -v, --version                     Show version
  -l, --list                        List installed Godot editor versions
  -r, --run [VERSION]               Run a Godot editor version (default: latest)
  -i, --install <VERSION>           Install a Godot editor version
  -d, --delete <VERSION>            Delete a Godot editor version

Modifiers:
  -m, --mono                        Download mono build (only with --install)
  -e, --experimental                Include experimental versions (only with --list --online)
  -o, --online                      List online versions (only with --list)

Examples:
  gim -l                            List installed editors
  gim -r                            Run latest editor
  gim -r 4.2                        Run specific version
  gim -i 4.2                        Install stable 4.2
  gim -i 4.2 -m                     Install mono build of 4.2
  gim -l -o                         List online versions
  gim -l -o -e                      List online experimental versions
```

## Changes

### 1. Rewrite `print_help()` in `gim.sh`

Replace the current implementation with:

- **Usage line**: Use `gim` instead of `$0`
- **Option alignment**: Pad flags to 36 characters, then description
- **Grouping**: Split into "Options" (core actions) and "Modifiers" (behavior flags)
- **Capitalization**: Start all descriptions with lowercase
- **Argument notation**: Use `<VERSION>` for required, `[VERSION]` for optional
- **Separator**: Replace `:` with spaces
- **Examples section**: Add 7 common usage examples

## Files affected

| File | Action |
|------|--------|
| `gim.sh` | Rewrite `print_help()` function |

## Verification

- Run `gim.sh --help` to verify output format
- Run `gim.sh -h` to verify short flag works
- Run `bash -n gim.sh` to verify syntax
