# Plan: Move actions from flags to subcommands

## Motivation

Actions (`-l`, `-r`, `-i`, `-d`) as flags create ambiguity and don't follow CLI conventions. Most tools (git, npm, docker) use subcommands for clear separation between commands and flags.

## Current vs Proposed

| Current (flags) | Proposed (subcommands) |
|-----------------|------------------------|
| `gim -l` | `gim list` |
| `gim -r` | `gim run` |
| `gim -r 4.7` | `gim run 4.7` |
| `gim -i 4.7` | `gim install 4.7` |
| `gim -d 4.7` | `gim delete 4.7` |
| `gim -i 4.7 -m` | `gim install 4.7 -m` |
| `gim -l -o` | `gim list -o` |
| `gim -l -o -e` | `gim list -oe` |

## Option classification

| Type | Items | Behavior |
|------|-------|----------|
| **Subcommands** | `list`, `run`, `install`, `delete` | Primary operations; first argument |
| **Modifiers** | `-m`, `-e`, `-o` | Boolean flags; combinable (`-oe`, `-oem`) |
| **Special** | `-h`, `-v` | Standalone flags |

## New help output

```
GIM - Godot Install Manager
Manage multiple Godot editor versions.

Usage: gim <command> [OPTIONS]

Commands:
  list                          List installed Godot editor versions
  run [VERSION]                 Run a Godot editor version (default: latest)
  install <VERSION>             Install a Godot editor version
  delete <VERSION>              Delete a Godot editor version

Global Options:
  -h, --help                    Show this help message
  -v, --version                 Show version

Modifiers:
  -m, --mono                    Download mono build (only with install)
  -e, --experimental            Include experimental versions (only with list)
  -o, --online                  List online versions (only with list)

Examples:
  gim list                      List installed editors
  gim list -o                   List online versions
  gim list -oe                  List online experimental versions
  gim run                       Run latest editor
  gim run 4.2                   Run specific version
  gim install 4.2               Install stable 4.2
  gim install 4.2 -m            Install mono build of 4.2
  gim delete 4.2                Delete a specific editor
```

## Implementation

### 1. Subcommand dispatch (first argument)

```bash
case "$1" in
  list|run|install|delete)
    _action="$1"
    shift
    ;;
  -h|--help)
    print_help
    exit 0
    ;;
  -v|--version)
    echo "$NAME_SHORT $VERSION"
    exit 0
    ;;
  "")
    echo "Error: No command specified" >&2
    print_help >&2
    exit 1
    ;;
  *)
    echo "Error: Unknown command '$1'" >&2
    print_help >&2
    exit 1
    ;;
esac
```

### 2. Parse modifiers and positional args (remaining args)

```bash
while test $# -gt 0; do
  case "$1" in
    -[meo][meo]*)
      # Decompose combined modifiers (e.g., -oe → -o -e)
      local opts="${1#-}"
      shift
      for (( i=0; i<${#opts}; i++ )); do
        set -- "-${opts:$i:1}" "$@"
      done
      continue
      ;;
    -m|--mono) _arg_mono="on" ;;
    -e|--experimental) _arg_experimental="on" ;;
    -o|--online) _arg_online="on" ;;
    -[meo])
      case "$1" in
        -m) _arg_mono="on" ;;
        -e) _arg_experimental="on" ;;
        -o) _arg_online="on" ;;
      esac
      ;;
    -*) error ;;
    *)
      # Positional argument (version for run/install/delete)
      if [ "$_action" = "run" ] && [ -z "$_arg_run" ]; then
        _arg_run="$1"
      elif [ "$_action" = "install" ] && [ -z "$_arg_install" ]; then
        _arg_install="$1"
      elif [ "$_action" = "delete" ] && [ -z "$_arg_delete" ]; then
        _arg_delete="$1"
      else
        error
      fi
      ;;
  esac
  shift
done
```

### 3. Dispatch to action function

```bash
case "$_action" in
  list) list_installed_editors ;;
  run) run_editor ;;
  install) install_editor ;;
  delete) delete_editor ;;
esac
```

## Files affected

| File | Action |
|------|--------|
| `gim.sh` | Rewrite `parse_args()`, update `print_help()`, update dispatch |

## Verification

- `gim list` → list installed editors
- `gim list -o` → list online versions
- `gim list -oe` → list online experimental
- `gim run` → run latest editor
- `gim run 4.7` → run specific version
- `gim install 4.7` → install 4.7
- `gim install 4.7 -m` → install mono build
- `gim delete 4.7` → delete 4.7
- `gim` → error: no command specified
- `gim unknown` → error: unknown command
- `bash -n gim.sh` → syntax check passes
