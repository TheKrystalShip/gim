# PLAN: Support Experimental Versions + Online Search + Mono Builds

## Status: Done

## Changes

### 1. Add Constant `MAX_SIMILAR_VERSIONS=5`
- Controls how many versions are shown when no exact match is found
- Placed in the Constants section of `gim.m4`

### 2. Add Helper `fetch_releases()`
- Calls `https://api.github.com/repos/godotengine/godot-builds/releases?per_page=100`
- Paginates if needed
- Parses JSON with `jq` — extracts `tag_name` and `prerelease` per release
- Stores results in global array `available_releases` (format: `tag_name|prerelease`)
- Caches results so multiple calls in the same invocation don't re-fetch

### 3. Add Helper `resolve_version()`
- Takes a search string (e.g. `4.7`, `4.8-dev`, `dev4`)
- **Exact match** on `tag_name` → return immediately
- **No exact match** → group `available_releases` by major version
  - Pick the latest stable and latest experimental for each major
  - Display sorted by major descending (highest first), experimental before stable within the same major
  - Exit with error

### 4. Modify `install_editor()`
- Add `jq` to binary dependency checks
- Call `fetch_releases()` to populate `available_releases`
- Call `resolve_version "$version"` to get exact tag
- Construct URL: `https://github.com/godotengine/godot-builds/releases/download/{tag}/Godot_v{tag}_{mono_}linux.x86_64.zip`
- Download and install as before

### 5. Add `--mono` / `-m` Argument
- `ARG_OPTIONAL_BOOLEAN([mono], m, [Download mono build instead of standard build])`
- Only affects `--install`
- Adds `mono_` segment to the download URL when enabled

### 6. Add `--online` / `-o` Action
- `ARG_OPTIONAL_ACTION([online], o, [List latest online versions])`
- Calls `fetch_releases()` then:
  - Groups all tags by major version
  - Picks the latest stable for each major
  - Picks the latest experimental across all majors
  - Prints formatted list sorted by major descending, experimental before stable

### 7. Update Dependency Checks
- Add `jq` to the binary check block at the top of `install_editor()` and `list_online()`
- Fail early with helpful message if `jq` is missing

### 8. Edge Cases
- **API rate limit (403)**: Print error suggesting `GITHUB_TOKEN` env var
- **Godot 3.x**: No Linux x86_64 editor zip — detect and report clearly
- **No `jq`**: Fail early with helpful message

## Files Changed

| File | Change |
|------|--------|
| `gim.m4` | Add constant, helpers, args, modify `install_editor()` |
| `gim.sh` | Regenerate via `argbash gim.m4 -o gim.sh` |
| `args.md` | Update docs for `--mono`, `--online` |
| `CLAUDE.md` | Add `jq` to dependencies |
| `PLAN.md` | This file — tracks implementation progress |

## Implementation Order

- [x] Create PLAN.md
- [x] Add MAX_SIMILAR_VERSIONS constant
- [x] Add fetch_releases() helper
- [x] Add resolve_version() helper
- [x] Modify install_editor() to use GitHub API
- [x] Add --mono / -m argument
- [x] Add --online / -o argument and list_online()
- [x] Update dependency checks (add jq)
- [x] Regenerate gim.sh
- [x] Update args.md documentation
- [x] Update CLAUDE.md dependencies
