# Plan: Support `-m` for All Subcommands with Fallback

**Status: Executed**

## Motivation

The `-m` flag currently only works with `install`. Users who install mono builds expect to run and delete them without specifying `-m` again. If only mono versions are installed, `run` and `delete` should fallback to the mono build.

## Changes

### 1. Update `find_editor_by_version()` (lines 169-189)

Add mono parameter and use filename-based matching:

```bash
find_editor_by_version() {
  local search_version="$1"
  local mono="$2"
  local editor_path=""
  local version_num="${search_version%%-*}"

  local pattern="${editor_file_name_start}_v${version_num}"
  if [ "$mono" = "on" ]; then
    pattern="${pattern}*_mono*"
  else
    pattern="${pattern}*_linux*"
  fi

  while IFS= read -r file; do
    if [ -n "$file" ]; then
      editor_path="$file"
      break
    fi
  done < <(find "$editors_dir" -maxdepth 1 -type f -name "$pattern" 2>/dev/null)

  if [ -z "$editor_path" ]; then
    echo "Error: No editor found matching version '$search_version' in $editors_dir" >&2
    return 1
  fi

  echo "$editor_path"
}
```

### 2. Update `run_editor()` (lines 374-392)

Add fallback logic with informational message: if specified mono flag not found, inform user and try opposite.

```bash
run_editor() {
  local search_version="$_arg_run"
  local mono="$_arg_mono"
  local editor_path

  if [ -z "$search_version" ]; then
    find_installed_editors
    if [ ${#installed_editors[@]} -eq 0 ]; then
      echo "No Godot editors found in $editors_dir" >&2
      exit 1
    fi
    local latest_version="${installed_editors[-1]}"
    editor_path=$(find_editor_by_version "$latest_version" "$mono" 2>/dev/null) || {
      if [ "$mono" = "on" ]; then
        echo "Mono build not found for $latest_version, using standard build." >&2
        editor_path=$(find_editor_by_version "$latest_version" "off") || exit 1
      else
        echo "Standard build not found for $latest_version, using mono build." >&2
        editor_path=$(find_editor_by_version "$latest_version" "on") || exit 1
      fi
    }
    echo "Running latest editor: $latest_version"
    "$editor_path" &
  else
    editor_path=$(find_editor_by_version "$search_version" "$mono" 2>/dev/null) || {
      if [ "$mono" = "on" ]; then
        echo "Mono build not found for $search_version, using standard build." >&2
        editor_path=$(find_editor_by_version "$search_version" "off") || exit 1
      else
        echo "Standard build not found for $search_version, using mono build." >&2
        editor_path=$(find_editor_by_version "$search_version" "on") || exit 1
      fi
    }
    echo "Running editor: $editor_path"
    "$editor_path" &
  fi
}
```

### 3. Update `delete_editor()` (lines 395-413)

Add fallback logic with informational message and error handling:

```bash
delete_editor() {
  local search_version="$_arg_delete"
  local mono="$_arg_mono"
  local editor_path

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

  echo "Found editor: $editor_path"
  read -r -p "Are you sure you want to delete this editor? [y/N] " response
  case "$response" in
    [yY][eE][sS]|[yY])
      rm "$editor_path"
      echo "Deleted $editor_path"
      ;;
    *)
      echo "Aborted."
      exit 0
      ;;
  esac
}
```

### 4. Update Help Text

Change from:
```
-m, --mono    Download mono build (only with install)
```

To:
```
-m, --mono    Use mono build (with install, run, or delete)
```

Add examples:
```
  gim run 4.2 -m                   Run mono build of 4.2
  gim delete 4.2 -m                Delete mono build of 4.2
```

## Files Affected

| File | Action |
|------|--------|
| `gim.sh` | Update `find_editor_by_version()` with mono parameter |
| `gim.sh` | Update `run_editor()` with fallback logic |
| `gim.sh` | Update `delete_editor()` with fallback logic |
| `gim.sh` | Update help text and examples |

## Fallback Behavior

| Command | Scenario | Behavior |
|---------|----------|----------|
| `gim run 4.7` | Only non-mono installed | Runs non-mono |
| `gim run 4.7` | Only mono installed | Runs mono |
| `gim run 4.7 -m` | Only non-mono installed | Prints "Mono build not found…", runs non-mono |
| `gim run 4.7 -m` | Only mono installed | Runs mono |
| `gim run 4.7` | Both installed | Runs non-mono |
| `gim run 4.7 -m` | Both installed | Runs mono |
| `gim delete 4.7` | Only non-mono installed | Deletes non-mono |
| `gim delete 4.7` | Only mono installed | Deletes mono |
| `gim delete 4.7 -m` | Only non-mono installed | Prints "Mono build not found…", deletes non-mono |
| `gim delete 4.7 -m` | Only mono installed | Deletes mono |
| `gim delete 4.7` | Both installed | Deletes non-mono |
| `gim delete 4.7 -m` | Both installed | Deletes mono |

## Verification

- `gim run 4.7 -m` → runs mono build
- `gim run 4.7` → runs non-mono build (or fallback to mono)
- `gim delete 4.7 -m` → deletes mono build
- `gim delete 4.7` → deletes non-mono build (or fallback to mono)
- `bash -n gim.sh` → syntax check passes
