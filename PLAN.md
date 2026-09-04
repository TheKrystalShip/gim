# PLAN: Add experimental flag and fix online listing

## Status: In Progress

## Previous Fix (Done)

Changed `-o` from `ARG_OPTIONAL_ACTION` to `ARG_OPTIONAL_BOOLEAN`, moved online list logic into `list_installed_editors()`.

## New Changes

### 1. Add constant `MAX_ONLINE_VERSIONS=5`
Separate from `MAX_SIMILAR_VERSIONS`. Controls how many versions are shown in `-ol` / `-oel` output.

### 2. Add argument `--experimental` / `-e`
`ARG_OPTIONAL_BOOLEAN([experimental], e, [Include experimental versions in online listing])`
Before `-o` in declaration order. Only affects `-ol` listing.

### 3. Rewrite online branch in `list_installed_editors()`
Two exclusive paths based on `$_arg_experimental`:
- **`_arg_experimental=off` (default)**: Latest stable per major.minor, sort descending, top `MAX_ONLINE_VERSIONS`
- **`_arg_experimental=on`**: All experimental tags, sort descending (`sort -Vr`), top `MAX_ONLINE_VERSIONS`

### 4. Update `args.md`
Add `-e` documentation.

### 5. Regenerate `gim.sh` and verify syntax

## Constants

| Constant | Default | Purpose |
|----------|---------|---------|
| `MAX_SIMILAR_VERSIONS` | 5 | "Did you mean?" fallback in `resolve_version()` |
| `MAX_ONLINE_VERSIONS` | 5 | Versions shown in `-ol` / `-oel` online listing |

## Result

| Command | Behavior |
|---------|----------|
| `-l` | Local editors (unchanged) |
| `-ol` | N latest stable online versions, descending |
| `-oel` or `-eol` | N latest experimental online versions, descending |
| `-lo`, `-le`, `-ole` | Don't work (`-l` stops processing) |
| `-o` alone | Ignored (boolean, no standalone effect) |
| `-e` alone | Ignored (boolean, no standalone effect) |

## Implementation Order

- [x] Update PLAN.md
- [x] Add MAX_ONLINE_VERSIONS constant
- [x] Add --experimental / -e argument
- [x] Rewrite online branch in list_installed_editors()
- [x] Update args.md
- [x] Regenerate gim.sh and verify syntax
