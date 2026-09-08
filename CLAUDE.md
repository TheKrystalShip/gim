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

## Helper Functions

These are internal functions used by the action functions. They live in the `# --- Helper Functions ---` section of `gim.sh`.

| Function | Signature | Purpose | Called by |
|----------|-----------|---------|-----------|
| `build_editor_pattern` | `(version, mono)` | Builds a glob pattern for finding editor files. Returns `*_mono*` or `*_linux*` variants. | `find_editor_by_version`, `is_version_installed` |
| `find_installed_editors` | `()` | Populates the `installed_editors` array with versions found in `$editors_dir`. | `run_editor`, `list_installed_editors` |
| `find_editor_by_version` | `(version, mono)` | Finds and echoes the full path to an editor binary matching a version. Returns 1 on miss. | `resolve_editor_with_fallback` |
| `is_version_installed` | `(version, mono)` | Returns 0 if a matching editor file exists, 1 otherwise. | `install_editor` |
| `parse_version_key` | `(tag)` | Sets `_pv_version` and `_pv_key` (major.minor) from a tag like `4.3.2-stable`. | `list_installed_editors`, `resolve_version` |
| `version_gt` | `(v1, v2)` | Returns 0 if v1 > v2 numerically (strips suffixes, compares major.minor.patch). | `list_installed_editors`, `resolve_version` |
| `http_fetch` | `(output, url)` | Downloads a URL to a file using curl or wget. Returns 1 if neither available. | `install_editor` |
| `check_online_dependencies` | `()` | Validates curl/wget and jq are installed. Exits 1 with error if not. | `list_installed_editors`, `install_editor` |
| `fetch_releases` | `()` | Fetches GitHub API releases into `available_releases` array. Caches; no-op if already populated. | `list_installed_editors`, `install_editor` |
| `resolve_version` | `(search_version)` | Resolves a partial version (e.g. `4.2`) to a full tag (e.g. `4.2.1-stable`). Returns 1 if no match, printing suggestions. | `install_editor` |
| `resolve_editor_with_fallback` | `(version, mono)` | Finds an editor, falling back to the other build type if the preferred one is missing. Echoes path or returns 1. | `run_editor`, `delete_editor` |

## Abstraction Principles

**Rule:** When two or more near-identical blocks of code exist, extract the shared logic into a helper function. Document the helper in CLAUDE.md.

This keeps action functions concise and ensures consistency — a fix in one place applies everywhere.

**Example — `resolve_editor_with_fallback`:**

Before refactoring, three separate blocks each duplicated the same mono/standard fallback logic:

```bash
# In run_editor (no version)
editor_path=$(find_editor_by_version "$latest_version" "$mono" 2>/dev/null) || {
  if [ "$mono" = "on" ]; then
    echo "Mono build not found for $latest_version, using standard build." >&2
    editor_path=$(find_editor_by_version "$latest_version" "off") || exit 1
  else
    echo "Standard build not found for $latest_version, using mono build." >&2
    editor_path=$(find_editor_by_version "$latest_version" "on") || exit 1
  fi
}

# In run_editor (with version) — identical block
editor_path=$(find_editor_by_version "$search_version" "$mono" 2>/dev/null) || {
  if [ "$mono" = "on" ]; then
    echo "Mono build not found for $search_version, using standard build." >&2
    editor_path=$(find_editor_by_version "$search_version" "off") || exit 1
  else
    echo "Standard build not found for $search_version, using mono build." >&2
    editor_path=$(find_editor_by_version "$search_version" "on") || exit 1
  fi
}

# In delete_editor — near-identical with extra nested error
editor_path=$(find_editor_by_version "$search_version" "$mono" 2>/dev/null) || {
  if [ "$mono" = "on" ]; then
    echo "Mono build not found for $search_version, using standard build." >&2
    editor_path=$(find_editor_by_version "$search_version" "off") || {
      echo "Error: No editor found matching version '$search_version' in $editors_dir" >&2
      exit 1
    }
  else
    echo "Standard build not found for $search_version, using mono build." >&2
    editor_path=$(find_editor_by_version "$search_version" "on") || {
      echo "Error: No editor found matching version '$search_version' in $editors_dir" >&2
      exit 1
    }
  fi
}
```

After extraction, each call site becomes a single line:

```bash
editor_path=$(resolve_editor_with_fallback "$version" "$mono") || exit 1
```

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
