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

find_installed_editors() {
  installed_editors=()
  if [ ! -d "$editors_dir" ]; then
    return
  fi
  while IFS= read -r file; do
    if [ -x "$file" ]; then
      version=$("$file" --version 2>/dev/null)
      if [ -n "$version" ]; then
        installed_editors+=("$version")
      fi
    fi
  done < <(find "$editors_dir" -maxdepth 1 -type f -iname "${editor_file_name_start}*" 2>/dev/null)
}

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

is_version_installed() {
  local search_version="$1"
  local mono="$2"
  # Extract version number before stability suffix (e.g., "4.7.2-stable" → "4.7.2")
  local version_num="${search_version%%-*}"

  # Build search pattern based on mono flag
  local pattern="${editor_file_name_start}_v${version_num}"
  if [ "$mono" = "on" ]; then
    pattern="${pattern}*_mono*"
  else
    pattern="${pattern}*_linux*"
  fi

  while IFS= read -r file; do
    if [ -n "$file" ]; then
      return 0
    fi
  done < <(find "$editors_dir" -maxdepth 1 -type f -name "$pattern" 2>/dev/null)
  return 1
}

list_installed_editors() {
  if [ "$_arg_online" = "on" ]; then
    check_online_dependencies
    fetch_releases

    echo "Online versions:"

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
      for entry in "${available_releases[@]}"; do
        local tag="${entry%%|*}"
        local prerelease="${entry#*|}"
        if [ "$prerelease" = "false" ]; then
          local major="${tag%%.*}"
          local remainder="${tag#*.}"
          local minor="${remainder%%.*}"
          local key="${major}.${minor}"
          if [ -z "${latest_stable[$key]}" ] || [[ "$tag" > "${latest_stable[$key]}" ]]; then
            latest_stable[$key]="$tag"
          fi
        fi
      done

      local count=0
      for key in $(for k in "${!latest_stable[@]}"; do echo "$k"; done | sort -t. -k1,1rn -k2,2rn); do
        if [ $count -ge $MAX_ONLINE_VERSIONS ]; then
          break
        fi
    echo "  ${latest_stable[$key]}" >&2
        ((count++))
      done
    fi
    return
  fi

  find_installed_editors

  if [ ${#installed_editors[@]} -eq 0 ]; then
    echo "No Godot editors found in $editors_dir"
    echo "Place Godot editors inside this folder to start using $NAME_SHORT."
    exit 0
  fi
  for editor in $(printf '%s\n' "${installed_editors[@]}" | sort -Vr); do
    echo "$editor"
  done
}

available_releases=()

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

  for entry in "${available_releases[@]}"; do
    local tag="${entry%%|*}"
    local prerelease="${entry#*|}"
    local major="${tag%%.*}"
    local remainder="${tag#*.}"
    local minor="${remainder%%.*}"

    if [ "$prerelease" = "true" ]; then
      if [ -z "$latest_experimental" ] || [[ "$tag" > "$latest_experimental" ]]; then
        latest_experimental="$tag"
      fi
    else
      local key="${major}.${minor}"
      if [ -z "${latest_stable[$key]}" ] || [[ "$tag" > "${latest_stable[$key]}" ]]; then
        latest_stable[$key]="$tag"
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
    echo "Godot $tag is already installed."
    exit 0
  fi

  local asset_suffix=""
  if [ "$mono" = "on" ]; then
    asset_suffix="_mono"
  fi


  # For some reason there's a zip file name difference between native and mono builds
  local zip_name
  if [ "$mono" = "on" ]; then
    zip_name="Godot_v${tag}${asset_suffix}_${platform}_${architecture}.zip"
  else
    zip_name="Godot_v${tag}${asset_suffix}_${platform}.${architecture}.zip"
  fi
  local download_url="https://github.com/godotengine/godot-builds/releases/download/${tag}/${zip_name}"

  local tmp_dir
  tmp_dir=$(mktemp -d)

  echo "Downloading $download_url..."
  if command -v curl &> /dev/null; then
    curl -fSL -o "$tmp_dir/$zip_name" "$download_url" || { echo "Download failed." >&2; rm -rf "$tmp_dir"; exit 1; }
  else
    wget -q -O "$tmp_dir/$zip_name" "$download_url" || { echo "Download failed." >&2; rm -rf "$tmp_dir"; exit 1; }
  fi

  echo "Extracting..."
  unzip -o -q "$tmp_dir/$zip_name" -d "$tmp_dir"

  rm "$tmp_dir/$zip_name"

  mkdir -p "$editors_dir"
  mv "$tmp_dir"/Godot_v* "$editors_dir/"
  chmod +x "$editors_dir"/Godot_v*

  tag="${tag}-mono"

  rm -rf "$tmp_dir"
  echo "Installed Godot $tag to $editors_dir"
}

# --- Main ---
parse_args "$@"

case "$_action" in
  list) list_installed_editors ;;
  run) run_editor ;;
  install) install_editor ;;
  delete) delete_editor ;;
esac
