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

APP_CONFIG_DIR="$XDG_CONFIG_HOME/gim"
APP_DATA_DIR="$XDG_DATA_HOME/gim"
editors_dir="$APP_DATA_DIR/editors/"
editor_file_name_start="Godot"

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
  local IFS='.'
  local major minor patch
  read -r major minor patch _ <<< "$version"
  patch="${patch%%-*}"
  local version_num="${major}.${minor}${patch:+.${patch}}"
  local pattern="${editor_file_name_start}_v${version_num}"
  if [ "$mono" = "on" ]; then
    echo "${pattern}*_mono*"
  else
    echo "${pattern}*_linux*"
  fi
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
  local editor_path=""
  local pattern
  pattern=$(build_editor_pattern "$search_version" "$mono")

  while IFS= read -r dir; do
    if [ -n "$dir" ]; then
      editor_path="$dir"
      break
    fi
  done < <(find "$editors_dir" -maxdepth 1 -type d -name "$pattern" 2>/dev/null)

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
  done < <(find "$editors_dir" -maxdepth 1 -type d -name "$pattern" 2>/dev/null)

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
    done < <(find "$editors_dir" -maxdepth 1 -type d -name "$pattern" 2>/dev/null)
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

  while IFS= read -r dir; do
    if [ -n "$dir" ]; then
      return 0
    fi
  done < <(find "$editors_dir" -maxdepth 1 -type d -name "$pattern" 2>/dev/null)
  return 1
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
    return
  fi

  find_installed_editors

  if [ ${#installed_editors[@]} -eq 0 ]; then
    echo "No Gdot editors installed. Install versions by running gim install <VERSION>" >&2
    exit 0
  fi
  for editor in $(printf '%s\n' "${installed_editors[@]}" | sort -Vr); do
    echo "$editor"
  done
}

available_releases=()

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

  local api_url="https://api.github.com/repos/godotengine/godot-builds/releases?per_page=100"
  local response
  local http_code

  if command -v curl &> /dev/null; then
    http_code=$(curl -s -w "%{http_code}" -o /tmp/gim_releases.json "$api_url")
  else
    http_code=$(wget -q -O /tmp/gim_releases.json "$api_url" 2>&1 && echo "200" || echo "000")
  fi

  if [ "$http_code" = "403" ]; then
    echo "Error: GitHub API rate limit exceeded." >&2
    echo "Set a GITHUB_TOKEN environment variable to increase the limit." >&2
    rm -f /tmp/gim_releases.json
    exit 1
  elif [ "$http_code" != "200" ]; then
    echo "Error: Failed to fetch releases from GitHub (HTTP $http_code)." >&2
    rm -f /tmp/gim_releases.json
    exit 1
  fi

  while IFS= read -r line; do
    available_releases+=("$line")
  done < <(jq -r '.[] | "\(.tag_name)|\(.prerelease)"' /tmp/gim_releases.json 2>/dev/null)
  rm -f /tmp/gim_releases.json
}

resolve_version() {
  local search_version="$1"

  for entry in "${available_releases[@]}"; do
    local tag="${entry%%|*}"
    if [[ "$tag" == ${search_version}* ]]; then
      echo "$tag"
      return 0
    fi
  done

  echo "No exact match found. Available versions:" >&2

  declare -A latest_stable
  local latest_experimental=""

  build_stable_map latest_stable

  for entry in "${available_releases[@]}"; do
    local tag="${entry%%|*}"
    local prerelease="${entry#*|}"
    if [ "$prerelease" = "true" ]; then
      if [ -z "$latest_experimental" ] || [[ "$tag" > "$latest_experimental" ]]; then
        latest_experimental="$tag"
      fi
    fi
  done

  local count=0
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
    version="${installed_editors[-1]}"
    display_label="latest editor: $version"
  else
    version="$search_version"
    display_label="editor"
  fi

  local editor_dir
  editor_dir=$(resolve_editor_with_fallback "$version" "$mono") || exit 1
  local editor_path
  editor_path=$(find_editor_executable_in_dir "$editor_dir") || exit 1
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
  unzip -o -q "$tmp_dir/$zip_name" -d "$tmp_dir"

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
parse_args "$@"

case "$_action" in
  list) list_installed_editors ;;
  run) run_editor ;;
  install) install_editor ;;
  delete) delete_editor ;;
esac
