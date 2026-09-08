# Refactor Plan: Simplify Near-Identical Branching in gim.sh

## Status: COMPLETE

All five patterns have been implemented and verified (syntax check passes).

---

## Overview

`gim.sh` contains multiple if-statements where both branches perform nearly identical
logic, differing only in a variable name, a string literal, or a fallback target.
These duplications hurt maintainability and increase the risk of inconsistency when
one branch is updated but the other is not.

---

## Pattern A: Mono/Linux File Pattern

**Status:** COMPLETE

**Locations:** `find_editor_by_version` (lines 177-182), `is_version_installed` (lines 206-211)

**Problem:** Both build an identical glob pattern from `$mono` — copy-pasted.

```bash
if [ "$mono" = "on" ]; then
  pattern="${pattern}*_mono*"
else
  pattern="${pattern}*_linux*"
fi
```

**Suggestion:** Extract to a helper:

```bash
build_editor_pattern() {
  local version="$1" mono="$2"
  local pattern="${editor_file_name_start}_v${version}"
  if [ "$mono" = "on" ]; then
    echo "${pattern}*_mono*"
  else
    echo "${pattern}*_linux*"
  fi
}
```

Both call sites replace ~5 lines with a single function call.

---

## Pattern B: Fallback Build Resolution

**Status:** COMPLETE

**Locations:** `run_editor` (lines 414-423), `run_editor` (lines 427-434), `delete_editor` (lines 446-459)

**Problem:** Three blocks follow the same pattern — try one build type, fall back to
the other on failure. They differ only in the version variable and error handling.

| Block | Version var | Error behavior |
|-------|-------------|----------------|
| `run_editor` (no version) | `$latest_version` | `exit 1` |
| `run_editor` (with version) | `$search_version` | `exit 1` |
| `delete_editor` | `$search_version` | nested `echo` + `exit 1` |

**Suggestion:** Extract to a helper:

```bash
resolve_editor_with_fallback() {
  local version="$1" mono="$2"
  local editor_path
  editor_path=$(find_editor_by_version "$version" "$mono" 2>/dev/null) && {
    echo "$editor_path"
    return 0
  }
  if [ "$mono" = "on" ]; then
    echo "Mono build not found for $version, using standard build." >&2
    editor_path=$(find_editor_by_version "$version" "off") || return 1
  else
    echo "Standard build not found for $version, using mono build." >&2
    editor_path=$(find_editor_by_version "$version" "on") || return 1
  fi
  echo "$editor_path"
}
```

`delete_editor`'s extra nested error message is redundant since `find_editor_by_version`
already prints the same error. The helper's `return 1` is sufficient for callers to
handle with their own `exit 1`.

---

## Pattern C: Curl vs Wget Abstraction

**Status:** COMPLETE

**Locations:** `fetch_releases` (lines 327-331), `install_editor` (lines 519-523)

**Problem:** Both branch on `command -v curl` to choose between curl and wget.

**Suggestion:** Extract a generic download helper:

```bash
http_fetch() {
  local output="$1" url="$2"
  if command -v curl &> /dev/null; then
    curl -fSL -o "$output" "$url"
  elif command -v wget &> /dev/null; then
    wget -q -O "$output" "$url"
  else
    return 1
  fi
}
```

`fetch_releases` needs the HTTP status code, so it would use a variant or keep a
thin wrapper. The `install_editor` download + error block (lines 519-523) collapses
to:

```bash
http_fetch "$tmp_dir/$zip_name" "$download_url" || {
  echo "Download failed." >&2
  rm -rf "$tmp_dir"
  exit 1
}
```

---

## Pattern D: `run_editor` Outer Branch Duplication

**Status:** COMPLETE

**Location:** `run_editor` (lines 403-438)

**Problem:** The two branches of the outer if/else differ only in:
1. How the version is resolved (`installed_editors[-1]` vs `$search_version`)
2. The log message (`"Running latest editor"` vs `"Running editor"`)

The inner fallback logic (lines 415-423 vs 427-434) is completely identical
except for the variable name.

**Suggestion:** Restructure to resolve the version first, then use a single
fallback path:

```bash
run_editor() {
  local search_version="$_arg_run"
  local mono="$_arg_mono"
  local version display_label

  if [ -z "$search_version" ]; then
    find_installed_editors
    [ ${#installed_editors[@]} -eq 0 ] && {
      echo "No Godot editors found in $editors_dir" >&2
      exit 1
    }
    version="${installed_editors[-1]}"
    display_label="latest editor: $version"
  else
    version="$search_version"
    display_label="editor"
  fi

  local editor_path
  editor_path=$(resolve_editor_with_fallback "$version" "$mono") || exit 1
  echo "Running $display_label"
  "$editor_path" &
}
```

---

## Pattern E: Zip Name Construction

**Status:** COMPLETE

**Location:** `install_editor` (lines 500-512)

**Problem:** Two separate if blocks handle the mono flag — one sets `$asset_suffix`,
the other constructs `$zip_name` with a slightly different pattern. Both are driven
by the same `$mono` flag.

```bash
local asset_suffix=""
if [ "$mono" = "on" ]; then
  asset_suffix="_mono"
fi

if [ "$mono" = "on" ]; then
  zip_name="Godot_v${tag}${asset_suffix}_${platform}_${architecture}.zip"
else
  zip_name="Godot_v${tag}${asset_suffix}_${platform}.${architecture}.zip"
fi
```

**Suggestion:** Merge into a single conditional — `$asset_suffix` is only used
here, so inline it:

```bash
local zip_name
if [ "$mono" = "on" ]; then
  zip_name="Godot_v${tag}_mono_${platform}_${architecture}.zip"
else
  zip_name="Godot_v${tag}_${platform}.${architecture}.zip"
fi
```

---

## Summary

| Pattern | Occurrences | Type | Savings |
|---------|-------------|------|---------|
| A: `build_editor_pattern` | 2 | Identical | Extract 1 helper |
| B: `resolve_editor_with_fallback` | 3 | Near-identical | Extract 1 helper, simplify 3 call sites |
| C: `http_fetch` | 2 | Similar (curl/wget) | Extract 1 helper |
| D: `run_editor` branches | 2 | Inner fallback identical | Restructure to single fallback path |
| E: Zip name construction | 2 | Same flag, split blocks | Merge into one conditional |

**Net effect:** ~50 lines of duplicated branching reduced to ~20 lines across
3-4 small helpers. The highest-impact changes are Pattern B (most duplication)
and Pattern A (exact duplicates).
