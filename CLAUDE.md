# CLAUDE.md

## Project Overview

GIM (Godot Install Manager) is a bash script that manages and launches multiple Godot engine versions on Linux. It uses pure bash for CLI argument parsing.

## Key Files

- `gim.sh` — Main script (single file to edit)

## Dependencies

- `curl` or `wget` — for downloading Godot releases
- `unzip` — for extracting downloaded archives
- `jq` — for parsing GitHub API responses

## Directory Structure (Runtime)

| Path | Purpose |
|------|---------|
| `~/.config/gim/` | Config directory (XDG_CONFIG_HOME) |
| `~/.local/share/gim/editors/` | Installed Godot editor binaries (XDG_DATA_HOME) |

## Conventions

- Follow existing code style (2-space indent, LF line endings per .editorconfig)
- XDG Base Directory spec compliance for all paths

## Argument Parsing

GIM uses subcommands with modifiers. Invoking `gim` without arguments shows the help message. Unknown commands show an error with a suggestion to run `--help`.

### Defaults
- `_action=""` — subcommand to execute
- `_arg_run=""`, `_arg_install=""`, `_arg_delete=""` — version arguments
- `_arg_mono="off"`, `_arg_experimental="off"`, `_arg_online="off"` — modifier flags

### `print_help()`
Prints usage information with subcommands, global options, modifiers, and examples.

### `parse_args(args...)`
Two-phase parsing:

1. **Subcommand dispatch** (first argument):
   - `list|run|install|delete` → sets `_action`
   - `-h|--help` → print help, exit 0
   - `-v|--version` → print version, exit 0
   - `""` (no args) → print help, exit 0
   - `*` (unknown) → error + "Run 'gim --help' for usage information.", exit 1

2. **Modifier and positional parsing** (remaining arguments):
   - Combined modifiers (`-[meo][meo]*`) → decompose into individual flags
   - `-m|--mono`, `-e|--experimental`, `-o|--online` → set modifier flags
   - Positional arguments → set version for run/install/delete
   - Unknown options → error, show help, exit 1
   - Validates required VERSION for install and delete

### Action Dispatch (end of script)

```bash
case "$_action" in
  list) list_installed_editors ;;
  run) run_editor ;;
  install) install_editor ;;
  delete) delete_editor ;;
esac
```

### Commands and Modifiers

| Type | Items | Behavior |
|------|-------|----------|
| Subcommands | `list`, `run`, `install`, `delete` | First argument; primary operations |
| Modifiers | `-m`, `-e`, `-o` | Boolean flags; combinable (`-oe`, `-oem`) |
| Special | `-h`, `-v` | Standalone flags |
