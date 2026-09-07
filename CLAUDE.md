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

### Defaults
All option variables are initialized at the top of `gim.sh`:
- Boolean args (`_arg_list`, `_arg_mono`, `_arg_experimental`, `_arg_online`) default to `"off"`
- Value args (`_arg_run`, `_arg_install`, `_arg_delete`) default to empty string
- `_arg_run_set` tracks whether `-r`/`--run` was explicitly provided

### `print_help()`
Prints usage information and all available options.

### `parse_args(args...)`
Main parsing loop. Iterates through `$@` with a `while test $# -gt 0` loop, matching each argument against a `case` statement:

- **Boolean options** (`-l`, `-m`, `-e`, `-o`): Set `_arg_*` to `"on"`. No `--no-` variants.
- **Value options** (`-i`, `-d`): Require a value. Accept `--option value`, `--option=value`, or `-o value`. Consume the next `$2` as the value and `shift`.
- **Optional value option** (`-r`, `--run`): Accept optional version. Sets `_arg_run_set=1`. If next arg is not a flag, consume it as the value.
- **Help/version** (`-h`, `-v`): Print and exit immediately.
- **Unknown options**: Print error message to stderr, show help, and exit with code 1.

### Argument Dispatch (end of script)
After `parse_args "$@"` runs, a conditional chain checks which `_arg_*` variable is set and calls the corresponding function:
- `_arg_list=on` → `list_installed_editors`
- `_arg_run_set=1` → `run_editor`
- `_arg_install` non-empty → `install_editor`
- `_arg_delete` non-empty → `delete_editor`
