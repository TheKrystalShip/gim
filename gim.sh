#!/usr/bin/env bash

# --- Defaults ---
_action=""
_arg_run=""
_arg_install=""
_arg_delete=""
_arg_mono="off"
_arg_experimental="off"
_arg_online="off"

# --- Constants ---
NAME_SHORT="GIM"
NAME_LONG="Godot Installation Manager"
VERSION="0.1.0"
MAX_SIMILAR_VERSIONS=5
MAX_ONLINE_VERSIONS=5

# --- XDG Base Directory Setup ---
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

APP_CONFIG_DIR="$XDG_CONFIG_HOME/gim"
APP_DATA_DIR="$XDG_DATA_HOME/gim"
APP_CACHE_DIR="$XDG_CACHE_HOME/gim"
editors_dir="$APP_DATA_DIR/editors/"
editor_file_name_start="Godot"

# --- Release cache ---
# Persist the GitHub release list across invocations so repeated `gim list -o`
# / `gim install` calls don't re-hit the API (unauthenticated limit: 60/hr).
RELEASES_CACHE_FILE="$APP_CACHE_DIR/releases.json"
GIM_RELEASES_TTL="${GIM_RELEASES_TTL:-3600}"   # seconds; overridable for tests

# --- Help ---
print_help()
{
  printf '%s\n' "Godot Install Manager - v${VERSION}
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
  -m, --mono                    Use mono build (with install, run, or delete)
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
  gim run 4.2 -m                Run mono build of 4.2
  gim delete 4.2 -m             Delete mono build of 4.2
  gim delete 4.2                Delete a specific editor"
}

# --- Error Handling ---
print_arg_error() {
  echo "Error: $1" >&2
  echo "Run 'gim --help' for usage information." >&2
  exit 1
}

# --- Parse Arguments ---
parse_args()
{
  # Subcommand dispatch
  case "${1:-}" in
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
      print_help
      exit 0
      ;;
    *)
      print_arg_error "Unknown command '$1'"
      ;;
  esac

  # Parse modifiers and positional args
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
      -m|--mono)
        _arg_mono="on"
        ;;
      -e|--experimental)
        _arg_experimental="on"
        ;;
      -o|--online)
        _arg_online="on"
        ;;
      -[meo])
        # Single modifier (fallback)
        case "$1" in
          -m) _arg_mono="on" ;;
          -e) _arg_experimental="on" ;;
          -o) _arg_online="on" ;;
        esac
        ;;
      -*)
        print_arg_error "Unknown option '$1'"
        ;;
      *)
        # Positional argument (version for run/install/delete)
        if [ "$_action" = "run" ] && [ -z "$_arg_run" ]; then
          _arg_run="$1"
        elif [ "$_action" = "install" ] && [ -z "$_arg_install" ]; then
          _arg_install="$1"
        elif [ "$_action" = "delete" ] && [ -z "$_arg_delete" ]; then
          _arg_delete="$1"
        else
          print_arg_error "Unexpected argument '$1'"
        fi
        ;;
    esac
    shift
  done

  # Validate required version arguments
  if [ "$_action" = "install" ] && [ -z "$_arg_install" ]; then
    print_arg_error "install requires a VERSION argument"
  fi
  if [ "$_action" = "delete" ] && [ -z "$_arg_delete" ]; then
    print_arg_error "delete requires a VERSION argument"
  fi
}

# --- Helper Functions ---

build_editor_pattern() {
  local version="$1" mono="$2"
  # Release tags (and thus zip/dir names on disk) use a dash before
  # prerelease parts (4.8-dev7, 4.3-stable), while `--version` output and
  # user input use a dot (4.8.dev7). Normalise to dots, then emit a [-.]
  # character class for non-numeric prerelease tokens so the pattern
  # matches both spellings on disk.
  version="${version//-/.}"
  local IFS='.'
  local major minor patch _
  read -r major minor patch _ <<< "$version"
  local version_num
  if [ -z "$patch" ]; then
    version_num="${major}.${minor}"
  elif [[ "$patch" =~ ^[0-9]+$ ]]; then
    version_num="${major}.${minor}.${patch}"
  else
    version_num="${major}.${minor}[-.]${patch}"
  fi
  local pattern="${editor_file_name_start}_v${version_num}"
  if [ "$mono" = "on" ]; then
    echo "${pattern}*_mono*"
  else
    echo "${pattern}*_linux*"
  fi
}

# Echo installed editor directories matching the given glob pattern.
# When mono is not "on", mono builds are excluded: the *_linux* part also
# appears in mono directory names, so without this filter a standard search
# could match a mono build (and vice versa is not a concern, as *_mono* is
# specific to mono builds).
collect_editor_dirs() {
  local pattern="$1" mono="$2"
  local dir
  while IFS= read -r dir; do
    [ -z "$dir" ] && continue
    if [ "$mono" != "on" ] && [[ "$(basename "$dir")" == *_mono_* ]]; then
      continue
    fi
    echo "$dir"
  done < <(find "$editors_dir" -maxdepth 1 -type d -name "$pattern" 2>/dev/null)
}

find_editor_executable_in_dir() {
  local dir="$1"
  local executable
  executable=$(find "$dir" -maxdepth 1 -type f -name 'Godot_v*' -print -quit 2>/dev/null)
  if [ -z "$executable" ]; then
    return 1
  fi
  echo "$executable"
}

find_installed_editors() {
  installed_editors=()
  if [ ! -d "$editors_dir" ]; then
    return
  fi
  while IFS= read -r dir; do
    if [ -d "$dir" ]; then
      local executable
      executable=$(find_editor_executable_in_dir "$dir") || continue
      local version
      version=$("$executable" --version 2>/dev/null)
      if [ -n "$version" ]; then
        installed_editors+=("$version")
      fi
    fi
  done < <(find "$editors_dir" -maxdepth 1 -type d -iname "${editor_file_name_start}*" 2>/dev/null)
}

find_editor_by_version() {
  local search_version="$1"
  local mono="$2"
  local pattern
  pattern=$(build_editor_pattern "$search_version" "$mono")

  local editor_path
  editor_path=$(collect_editor_dirs "$pattern" "$mono" | head -n 1)

  if [ -z "$editor_path" ]; then
    echo "Error: No editor found matching version '$search_version' in $editors_dir" >&2
    return 1
  fi

  echo "$editor_path"
}

find_editors_by_version() {
  local search_version="$1" mono="$2"
  local pattern
  pattern=$(build_editor_pattern "$search_version" "$mono")

  local -a results=()
  while IFS= read -r dir; do
    [ -n "$dir" ] && results+=("$dir")
  done < <(collect_editor_dirs "$pattern" "$mono")

  if [ ${#results[@]} -eq 0 ]; then
    local fallback_mono
    if [ "$mono" = "on" ]; then
      echo "Mono build not found for $search_version, trying standard build." >&2
      fallback_mono="off"
    else
      echo "Standard build not found for $search_version, trying mono build." >&2
      fallback_mono="on"
    fi
    pattern=$(build_editor_pattern "$search_version" "$fallback_mono")
    while IFS= read -r dir; do
      [ -n "$dir" ] && results+=("$dir")
    done < <(collect_editor_dirs "$pattern" "$fallback_mono")
  fi

  for r in "${results[@]}"; do
    echo "$r"
  done
}

is_version_installed() {
  local search_version="$1"
  local mono="$2"
  local pattern
  pattern=$(build_editor_pattern "$search_version" "$mono")

  local match
  match=$(collect_editor_dirs "$pattern" "$mono" | head -n 1)
  [ -n "$match" ]
}

build_stable_map() {
  local -n _map=$1
  for entry in "${available_releases[@]}"; do
    local tag="${entry%%|*}"
    local prerelease="${entry#*|}"
    if [ "$prerelease" = "false" ]; then
      parse_version_key "$tag"
      local key="$_pv_key"
      if [ -z "${_map[$key]}" ] || version_gt "$tag" "${_map[$key]}"; then
        _map[$key]="$tag"
      fi
    fi
  done
}

parse_version_key() {
  local tag="$1"
  local version="${tag%%-*}"
  local major="${version%%.*}"
  local remainder="${version#*.}"
  local minor="${remainder%%.*}"
  _pv_version="$version"
  _pv_key="${major}.${minor}"
}

# Compare two version strings numerically (greater than).
# Strips suffixes (e.g., -stable, -rc1) and compares major.minor.patch.
version_gt() {
  local v1="${1%%-*}" v2="${2%%-*}"
  IFS='.' read -r major1 minor1 patch1 <<< "$v1"
  IFS='.' read -r major2 minor2 patch2 <<< "$v2"
  [ "${major1:-0}" -gt "${major2:-0}" ] ||
  { [ "${major1:-0}" -eq "${major2:-0}" ] && [ "${minor1:-0}" -gt "${minor2:-0}" ]; } ||
  { [ "${major1:-0}" -eq "${major2:-0}" ] && [ "${minor1:-0}" -eq "${minor2:-0}" ] && [ "${patch1:-0}" -gt "${patch2:-0}" ]; }
}

list_installed_editors() {
  if [ "$_arg_online" = "on" ]; then
    check_online_dependencies
    fetch_releases

    echo "Online versions:" >&2

    if [ "$_arg_experimental" = "on" ]; then
      local experimental_tags=()
      for entry in "${available_releases[@]}"; do
        local tag="${entry%%|*}"
        local prerelease="${entry#*|}"
        if [ "$prerelease" = "true" ]; then
          experimental_tags+=("$tag")
        fi
      done

      local count=0
      for tag in $(printf '%s\n' "${experimental_tags[@]}" | sort -Vr); do
        if [ $count -ge $MAX_ONLINE_VERSIONS ]; then
          break
        fi
        echo "  $tag"
        ((count++))
      done
    else
      declare -A latest_stable
      build_stable_map latest_stable

      local count=0
      for key in $(for k in "${!latest_stable[@]}"; do echo "$k"; done | sort -t. -k1,1rn -k2,2rn); do
        if [ $count -ge $MAX_ONLINE_VERSIONS ]; then
          break
        fi
    echo "  ${latest_stable[$key]}"
        ((count++))
      done
    fi
    return 0
  fi

  find_installed_editors

  if [ ${#installed_editors[@]} -eq 0 ]; then
    echo "No Godot editors installed. Install versions by running gim install <VERSION>" >&2
    exit 0
  fi
  for editor in $(printf '%s\n' "${installed_editors[@]}" | sort -Vr); do
    echo "$editor"
  done
}

available_releases=()
releases_from_cache="false"   # true when the in-memory list came from disk cache

# --- Release cache helpers -------------------------------------------------
# The cache is a single JSON object {fetched_at, releases}. Keeping payload and
# timestamp in one file makes the write atomic (one mv), and the jq wrap also
# validates the JSON so malformed responses are never cached.

# cache_is_fresh — 0 if a readable cache exists and is within GIM_RELEASES_TTL.
cache_is_fresh() {
  [ -f "$RELEASES_CACHE_FILE" ] || return 1
  local fetched_at now
  fetched_at=$(jq -r '.fetched_at // empty' "$RELEASES_CACHE_FILE" 2>/dev/null)
  [ -n "$fetched_at" ] || return 1
  now=$(date +%s)
  [ $((now - fetched_at)) -lt "$GIM_RELEASES_TTL" ]
}

# cache_load_releases — populate available_releases from the on-disk cache.
# Returns 1 on any read/parse failure (treated as a miss, never fatal).
cache_load_releases() {
  [ -f "$RELEASES_CACHE_FILE" ] || return 1
  local line
  available_releases=()
  while IFS= read -r line; do
    available_releases+=("$line")
  done < <(jq -r '.releases[] | "\(.tag_name)|\(.prerelease)"' "$RELEASES_CACHE_FILE" 2>/dev/null)
  [ ${#available_releases[@]} -gt 0 ] || return 1
  releases_from_cache="true"
}

# cache_write_releases <raw-json-file> — wrap with fetched_at and publish
# atomically. The mktemp MUST live in the cache dir so mv stays on one
# filesystem (cross-device mv is not atomic).
cache_write_releases() {
  local raw="$1"
  mkdir -p "$APP_CACHE_DIR" || return 1
  chmod 700 "$APP_CACHE_DIR" || return 1
  local tmp now
  tmp=$(mktemp "$APP_CACHE_DIR/.releases.XXXXXX") || return 1
  now=$(date +%s)
  if ! jq --argjson ts "$now" '{fetched_at: $ts, releases: .}' "$raw" > "$tmp" 2>/dev/null; then
    rm -f "$tmp"
    return 1
  fi
  mv -f "$tmp" "$RELEASES_CACHE_FILE"
}

# cache_invalidate — drop the on-disk cache (used by the Option C retry).
cache_invalidate() {
  rm -f "$RELEASES_CACHE_FILE"
}

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

check_online_dependencies() {
  if ! command -v curl &> /dev/null && ! command -v wget &> /dev/null; then
    echo "Error: Neither curl nor wget is installed." >&2
    exit 1
  fi
  if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed." >&2
    exit 1
  fi
}

fetch_releases() {
  if [ ${#available_releases[@]} -gt 0 ]; then
    return
  fi

  # Fresh cache short-circuit: serve from disk, no network.
  if cache_is_fresh && cache_load_releases; then
    echo "Using cached releases." >&2
    return
  fi

  echo "Fetching online releases..." >&2

  local api_url="https://api.github.com/repos/godotengine/godot-builds/releases?per_page=100"
  local http_code
  local response_file
  response_file=$(mktemp) || exit 1

  if command -v curl &> /dev/null; then
    http_code=$(curl -s -w "%{http_code}" -o "$response_file" "$api_url")
  else
    http_code=$(wget -q -O "$response_file" "$api_url" 2>&1 && echo "200" || echo "000")
  fi

  if [ "$http_code" = "403" ] || [ "$http_code" != "200" ]; then
    # Stale-fallback: a stale version list beats a hard error. If a cache
    # exists (even expired), load it and warn rather than failing.
    if cache_load_releases; then
      if [ "$http_code" = "403" ]; then
        echo "Warning: GitHub API rate limit exceeded; using stale cached releases." >&2
      else
        echo "Warning: Failed to fetch releases (HTTP $http_code); using stale cached releases." >&2
      fi
      rm -f "$response_file"
      return
    fi
    if [ "$http_code" = "403" ]; then
      echo "Error: GitHub API rate limit exceeded." >&2
      echo "Set a GITHUB_TOKEN environment variable to increase the limit." >&2
    else
      echo "Error: Failed to fetch releases from GitHub (HTTP $http_code)." >&2
    fi
    rm -f "$response_file"
    exit 1
  fi

  available_releases=()
  local line
  while IFS= read -r line; do
    available_releases+=("$line")
  done < <(jq -r '.[] | "\(.tag_name)|\(.prerelease)"' "$response_file" 2>/dev/null)
  releases_from_cache="false"
  # Best-effort cache publish; failure here must not break the fetch.
  cache_write_releases "$response_file" || true
  rm -f "$response_file"
}

# __match_release <search> — echo the first tag matching the prefix; 1 on miss.
__match_release() {
  local search_version="$1"
  local entry tag
  for entry in "${available_releases[@]}"; do
    tag="${entry%%|*}"
    if [[ "$tag" == ${search_version}* ]]; then
      echo "$tag"
      return 0
    fi
  done
  return 1
}

# __print_version_suggestions — stderr list of the newest stable per major.minor
# (up to MAX_SIMILAR_VERSIONS) plus the latest experimental, for a resolve miss.
__print_version_suggestions() {
  echo "No exact match found. Available versions:" >&2

  declare -A latest_stable
  local latest_experimental=""

  build_stable_map latest_stable

  local entry tag prerelease
  for entry in "${available_releases[@]}"; do
    tag="${entry%%|*}"
    prerelease="${entry#*|}"
    if [ "$prerelease" = "true" ]; then
      if [ -z "$latest_experimental" ] || [[ "$tag" > "$latest_experimental" ]]; then
        latest_experimental="$tag"
      fi
    fi
  done

  local count=0 key
  for key in $(for k in "${!latest_stable[@]}"; do echo "$k"; done | sort -t. -k1,1n -k2,2n); do
    if [ $count -ge $MAX_SIMILAR_VERSIONS ]; then
      break
    fi
    echo "  ${latest_stable[$key]}" >&2
    ((count++))
  done

  if [ -n "$latest_experimental" ] && [ $count -lt $MAX_SIMILAR_VERSIONS ]; then
    echo "  $latest_experimental" >&2
  fi
}

resolve_version() {
  local search_version="$1"
  local tag

  if tag=$(__match_release "$search_version"); then
    echo "$tag"
    return 0
  fi

  # Option C: a miss against a *cached* list may just be a stale snapshot (the
  # version shipped within the last TTL). Invalidate, re-fetch once, and retry
  # before concluding it doesn't exist. The retry sets releases_from_cache=false
  # so this cannot loop.
  if [ "$releases_from_cache" = "true" ]; then
    cache_invalidate
    available_releases=()
    fetch_releases
    if tag=$(__match_release "$search_version"); then
      echo "$tag"
      return 0
    fi
  fi

  __print_version_suggestions
  return 1
}

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

run_editor() {
  local search_version="$_arg_run"
  local mono="$_arg_mono"
  local version display_label

  if [ -z "$search_version" ]; then
    find_installed_editors
    if [ ${#installed_editors[@]} -eq 0 ]; then
      echo "No Godot editors found in $editors_dir" >&2
      exit 1
    fi
    # Latest first regardless of build type: if the newest build is a mono
    # build it must still be the one that runs. For equal versions, sort -Vr
    # orders the standard build ahead of the mono build, so plain `gim run`
    # picks the standard build and mono must be requested explicitly.
    mapfile -t installed_editors < <(printf '%s\n' "${installed_editors[@]}" | sort -Vr)
    version="${installed_editors[0]}"
    display_label="latest editor: $version"
    # The version string itself identifies the build type (".mono." for mono
    # builds), so honour it when -m was not passed.
    if [ "$mono" = "off" ] && [[ "$version" == *.mono.* ]]; then
      mono="on"
    fi
  else
    version="$search_version"
    # display_label is resolved below, once the editor is located
  fi

  local editor_dir
  editor_dir=$(resolve_editor_with_fallback "$version" "$mono") || exit 1
  local editor_path
  editor_path=$(find_editor_executable_in_dir "$editor_dir") || exit 1

  if [ -z "$display_label" ]; then
    # Explicit version requested: name the resolved installed build (e.g.
    # 4.7.2.stable.official...), matching the detail plain `gim run` gives,
    # instead of the bare word "editor" or the partial search string.
    local resolved_version
    resolved_version=$("$editor_path" --version 2>/dev/null)
    display_label="editor: ${resolved_version:-$version}"
  fi

  echo "Running $display_label" >&2
  "$editor_path" &
}

delete_editor() {
  local search_version="$_arg_delete"
  local mono="$_arg_mono"
  local editor_dir
  local -a matches=()

  while IFS= read -r dir; do
    [ -n "$dir" ] && matches+=("$dir")
  done < <(find_editors_by_version "$search_version" "$mono")

  if [ ${#matches[@]} -eq 0 ]; then
    echo "Error: No editor found matching version '$search_version' in $editors_dir" >&2
    exit 1
  fi

  # Sort matches in descending version order by basename
  if [ ${#matches[@]} -gt 1 ]; then
    local sorted_file
    sorted_file=$(mktemp)
    for dir in "${matches[@]}"; do
      echo "$(basename "$dir")|$dir" >> "$sorted_file"
    done
    local -a sorted_matches=()
    while IFS='|' read -r name path; do
      sorted_matches+=("$path")
    done < <(sort -t'|' -k1,1Vr "$sorted_file")
    rm -f "$sorted_file"
    matches=("${sorted_matches[@]}")
  fi

  if [ ${#matches[@]} -eq 1 ]; then
    editor_dir="${matches[0]}"
  else
    echo "Multiple editors found matching version '$search_version':" >&2
    local i=1
    for dir in "${matches[@]}"; do
      echo "  $i) $(basename "$dir")" >&2
      ((i++))
    done
    local choice
    while true; do
      read -r -p "Enter number (1-${#matches[@]}): " choice
      if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#matches[@]}" ]; then
        editor_dir="${matches[$((choice-1))]}"
        break
      fi
      echo "Invalid choice. Please enter a number between 1 and ${#matches[@]}." >&2
    done
  fi

  echo "Found editor: $(basename "$editor_dir")" >&2
  read -r -p "Are you sure you want to delete this editor? [y/N] " response
  case "$response" in
    [yY][eE][sS]|[yY])
      rm -rf "$editor_dir"
      echo "Deleted $editor_dir" >&2
      ;;
    *)
      echo "Aborted." >&2
      exit 0
      ;;
  esac
}

install_editor() {
  local version="$_arg_install"
  local mono="$_arg_mono"
  local platform="linux"
  local architecture="x86_64"

  check_online_dependencies

  if ! command -v unzip &> /dev/null; then
    echo "Error: unzip is not installed." >&2
    exit 1
  fi

  fetch_releases

  local tag
  tag=$(resolve_version "$version") || exit 1

  # Check if version is already installed
  if is_version_installed "$tag" "$mono"; then
    echo "Godot $tag is already installed." >&2
    exit 0
  fi

  # For some reason there's a zip file name difference between native and mono builds when downloading
  local zip_name
  if [ "$mono" = "on" ]; then
    zip_name="Godot_v${tag}_mono_${platform}_${architecture}.zip"
  else
    zip_name="Godot_v${tag}_${platform}.${architecture}.zip"
  fi
  local download_url="https://github.com/godotengine/godot-builds/releases/download/${tag}/${zip_name}"

  local tmp_dir
  tmp_dir=$(mktemp -d)

  echo "Downloading $download_url" >&2
  http_fetch "$tmp_dir/$zip_name" "$download_url" || {
    echo "Download failed." >&2
    rm -rf "$tmp_dir"
    exit 1
  }

  echo "Extracting \"$zip_name\"" >&2
  if ! unzip -o -q "$tmp_dir/$zip_name" -d "$tmp_dir"; then
    echo "Error: Failed to extract $zip_name." >&2
    rm -rf "$tmp_dir"
    exit 1
  fi

  rm "$tmp_dir/$zip_name"

  mkdir -p "$editors_dir"

  # Remove any pre-existing files/dirs that would conflict with the extracted content
  local extracted_items=("$tmp_dir"/Godot_v*)
  for item in "${extracted_items[@]}"; do
    local base
    base=$(basename "$item")
    rm -rf "${editors_dir:?}/${base}"
  done

  # Move extracted content to editors_dir, wrapping non-mono files in a directory
  for item in "$tmp_dir"/Godot_v*; do
    [ -e "$item" ] || continue
    local base
    base=$(basename "$item")
    if [ -d "$item" ]; then
      mv "$item" "$editors_dir/"
    else
      mkdir -p "$editors_dir/$base"
      mv "$item" "$editors_dir/$base/"
    fi
  done

  # Make all editor directories and their contents accessible
  find "$editors_dir" -maxdepth 1 -type d -name 'Godot_v*' -exec chmod +x {}/Godot_v* \; 2>/dev/null
  find "$editors_dir" -maxdepth 1 -type d -name 'Godot_v*' -exec chmod 755 {} \; 2>/dev/null

  if [ "$mono" = "on" ]; then
    tag="${tag}-mono"
  fi

  rm -rf "$tmp_dir"
  echo "Installed Godot $tag to $editors_dir" >&2
}

# --- Main ---
main() {
  parse_args "$@"

  case "$_action" in
    list) list_installed_editors ;;
    run) run_editor ;;
    install) install_editor ;;
    delete) delete_editor ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
