# Plan: Use dedicated folders for all editor installs

## Context

The previous fix flattened mono builds into single files. The user now wants **all** builds (mono and non-mono) installed into dedicated subdirectories under `editors_dir`. This is needed because mono builds include `GodotSharp/` which must live alongside the executable.

### Zip structure (verified)
- **Non-mono**: extracts to a single file `Godot_v4.7.2-stable_linux.x86_64`
- **Mono**: extracts to a directory `Godot_v4.7.2-stable_mono_linux_x86_64/` containing the executable + `GodotSharp/`

### Target layout
```
editors_dir/
  Godot_v4.7.2-stable_linux.x86_64/
    Godot_v4.7.2-stable_linux.x86_64        (executable)
  Godot_v4.7.2-stable_mono_linux_x86_64/
    Godot_v4.7.2-stable_mono_linux.x86_64   (executable)
    GodotSharp/                             (mono runtime)
```

## Changes

### 1. New helper: `find_editor_executable_in_dir` (after `build_editor_pattern`)

Finds the Godot executable inside an editor directory.

### 2. `find_installed_editors` — change `find -type f` to `find -type d`

Discover editor directories, then find the executable inside each.

### 3. `find_editor_by_version` — change `find -type f` to `find -type d`

Match editor directories by pattern, return the directory path.

### 4. `is_version_installed` — change `find -type f` to `find -type d`

Check for directory existence instead of file.

### 5. `run_editor` — find executable inside the directory

After resolving the directory, use `find_editor_executable_in_dir` to get the binary.

### 6. `delete_editor` — use `rm -rf` on the directory

Remove the entire editor directory, not just a single file.

### 7. `install_editor` — rewrite post-extraction logic

- For mono: move the extracted directory as-is
- For non-mono: wrap the extracted file in a dedicated directory
- Remove the flattening logic

### 8. Fix output routing violations (stdout/stderr convention)

Per CLAUDE.md: primary output → stdout, log/progress/errors → stderr.

| Line | Current | Fix |
|------|---------|-----|
| 283 | `echo "  ${latest_stable[$key]}" >&2` | Remove `>&2` (version data → stdout) |
| 293 | `echo "No Godot editors found..."` | Add `>&2` (log message → stderr) |
| 294 | `echo "Place Godot editors inside..."` | Add `>&2` (log message → stderr) |
| 444 | `echo "Running $display_label"` | Add `>&2` (log message → stderr) |
| 455 | `echo "Found editor: $editor_path"` | Add `>&2` (log message → stderr) |
| 460 | `echo "Deleted $editor_path"` | Add `>&2` (log message → stderr) |
| 463 | `echo "Aborted."` | Add `>&2` (log message → stderr) |
| 489 | `echo "Godot $tag is already installed."` | Add `>&2` (log message → stderr) |
| 505 | `echo "Downloading $download_url..."` | Add `>&2` (progress → stderr) |
| 513 | `echo "Extracting \"$zip_name\""` | Add `>&2` (progress → stderr) |
| 544 | `echo "Installed Godot $tag to $editors_dir"` | Add `>&2` (log message → stderr) |

## Verification

1. `rm -rf ~/.local/share/gim/editors/Godot_v4.7.2*`
2. `./gim.sh install -m 4.7` — mono directory with executable + GodotSharp; progress messages on stderr
3. `./gim.sh install 4.7` — standard directory with executable; progress messages on stderr
4. `./gim.sh list` — both versions appear on stdout; no log noise on stdout
5. `./gim.sh run 4.7 -m` — launches mono editor; "Running ..." on stderr
6. `./gim.sh list -o | head` — version strings only on stdout, "Online versions:" header on stderr
