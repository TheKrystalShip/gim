# Plan: Remove Argbash, rewrite argument parsing in pure bash

## Motivation

Argbash can't handle optional values for options (the `-r` issue). Beyond that, it adds a build dependency, a M4 template layer, and generates code that's hard to maintain. Replacing it with a straightforward bash `case` parser removes all of this.

## What gets replaced

| Argbash artifact | Replacement |
|---|---|
| `gim.m4` (M4 template) | Delete entirely |
| `ARG_*` declarations at top of gim.sh | Delete |
| `die()` function | Inline error messages |
| `begins_with_short_option()` | Not needed |
| `_PRINT_HELP` pattern | Not needed |
| `print_help()` | Rewrite (simpler) |
| `parse_commandline()` | Rewrite as `parse_args()` |
| `# [ <-- needed because of Argbash` markers | Delete |

## Changes

### 1. Delete `gim.m4`

No longer the source of truth. `gim.sh` becomes the single file to edit.

### 2. Rewrite `gim.sh`

Remove everything above the constants section (lines 1-178). Replace with:

- **Initialization block** — set all `_arg_*` defaults
- **`print_help()`** — rewritten, no argbash boilerplate, no `--no-` variants
- **`parse_args()`** — while/case loop handling all options:
  - `-h`/`--help` → print help, exit
  - `-v`/`--version` → print version, exit
  - `-l`/`--list` → set `_arg_list="on"`
  - `-r`/`--run [VERSION]` / `--run=VERSION` → optional value, sets `_arg_run_set=1` and optionally `_arg_run`
  - `-i`/`--install VERSION` / `--install=VERSION` → required value
  - `-d`/`--delete VERSION` / `--delete=VERSION` → required value
  - `-m`/`--mono` → set `_arg_mono="on"`
  - `-e`/`--experimental` → set `_arg_experimental="on"`
  - `-o`/`--online` → set `_arg_online="on"`
  - `*` → error + print help to stderr
- **Call `parse_args "$@"`** instead of `parse_commandline "$@"`

### 3. Boolean flags — no `--no-` variants

| Before | After |
|---|---|
| `-l`/`--list`/`--no-list` | `-l`/`--list` |
| `-m`/`--mono`/`--no-mono` | `-m`/`--mono` |
| `-e`/`--experimental`/`--no-experimental` | `-e`/`--experimental` |
| `-o`/`--online`/`--no-online` | `-o`/`--online` |

Each is off by default; no toggling needed.

### 4. Update dispatch logic

Change `elif [ -n "$_arg_run" ]` to `elif [ "$_arg_run_set" = 1 ]` so `-r` without a version triggers `run_editor`.

### 5. Delete `.opencode/` folder

Stale plans directory, no longer needed.

### 6. Update `CLAUDE.md`

- Remove "Argbash Parse Code" section
- Add "Argument Parsing" section documenting `print_help()`, `parse_args()`, and variable defaults
- Remove argbash from dependencies/overview references
- Update Build/Regenerate section (no more `argbash` command)
- Update Key Files (`gim.m4` no longer exists)

### 7. Update `args.md`

Remove `--no-` references from boolean flags.

## Files affected

| File | Action |
|---|---|
| `gim.m4` | Delete |
| `gim.sh` | Rewrite (argbash removal, pure bash parser) |
| `CLAUDE.md` | Update (remove argbash references, document new parser) |
| `args.md` | Update (remove `--no-` from boolean flags) |
| `PLAN.md` | Replace with this plan's content |
| `.opencode/` | Delete |

## Usage examples after change

```
gim -r            # run latest, then exit
gim -r 4.2        # run specific version, then exit
gim -r=4.2        # run specific version (equals form)
gim --run         # run latest, then exit
gim --run 4.2     # run specific version, then exit
gim -i 4.2 -m     # install 4.2 mono build
```

## Limitations compared to argbash

- No combined short options (`-lm` won't work; must use `-l -m`). This is fine — the current argbash decomposition of combined options is complex and rarely used.
