#!/usr/bin/env bash

# --- Defaults ---
_arg_list="off"
_arg_run=""
_arg_run_set=0
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
  printf '%s\n' "GIM - Godot Install Manager
Manage multiple Godot editor versions."
  printf 'Usage: %s [-h|--help] [-v|--version] [-l|--list] [-r|--run [VERSION]] [-i|--install VERSION] [-d|--delete VERSION] [-m|--mono] [-e|--experimental] [-o|--online]\n' "$0"
  printf '\t%s\n' "-h, --help: Prints help"
  printf '\t%s\n' "-v, --version: Prints version"
  printf '\t%s\n' "-l, --list: list installed Godot editor versions"
  printf '\t%s\n' "-r, --run [VERSION]: run a specific installed Godot editor version; if omitted, run latest"
  printf '\t%s\n' "-i, --install VERSION: install a specific Godot editor version; use --list --online to see available versions"
  printf '\t%s\n' "-d, --delete VERSION: delete a specific installed Godot editor"
  printf '\t%s\n' "-m, --mono: download mono build instead of standard build; only works with --install"
  printf '\t%s\n' "-e, --experimental: include experimental versions in online listing; only works with --online"
  printf '\t%s\n' "-o, --online: list latest online editor versions; only works with --list"
}

# --- Parse Arguments ---
parse_args()
{
  while test $# -gt 0; do
    case "$1" in
      -h|--help)
        print_help
        exit 0
        ;;
      -v|--version)
        echo "$NAME_SHORT $VERSION"
        exit 0
        ;;
      -l|--list)
        _arg_list="on"
        ;;
      -r|--run)
        _arg_run_set=1
        if [ -n "$2" ] && [ "${2:0:1}" != "-" ]; then
          _arg_run="$2"
          shift
        fi
        ;;
      --run=*)
        _arg_run_set=1
        _arg_run="${1#--run=}"
        ;;
      -i|--install)
        if [ -z "$2" ] || [ "${2:0:1}" = "-" ]; then
          echo "Error: Missing required value for '$1'" >&2
          print_help >&2
          exit 1
        fi
        _arg_install="$2"
        shift
        ;;
      --install=*)
        _arg_install="${1#--install=}"
        ;;
      -d|--delete)
        if [ -z "$2" ] || [ "${2:0:1}" = "-" ]; then
          echo "Error: Missing required value for '$1'" >&2
          print_help >&2
          exit 1
        fi
        _arg_delete="$2"
        shift
        ;;
      --delete=*)
        _arg_delete="${1#--delete=}"
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
      *)
        echo "Error: Unknown option '$1'" >&2
        print_help >&2
        exit 1
        ;;
    esac
    shift
  done
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
  local editor_path=""

  while IFS= read -r file; do
    if [ -x "$file" ]; then
      version=$("$file" --version 2>/dev/null)
      if [ -n "$version" ] && echo "$version" | grep -qF "$search_version"; then
        editor_path="$file"
        break
      fi
    fi
  done < <(find "$editors_dir" -maxdepth 1 -type f -iname "${editor_file_name_start}*" 2>/dev/null)

  if [ -z "$editor_path" ]; then
    echo "Error: No editor found matching version '$search_version' in $editors_dir" >&2
    return 1
  fi

  echo "$editor_path"
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
  local editor_path

  if [ -z "$search_version" ]; then
    find_installed_editors
    if [ ${#installed_editors[@]} -eq 0 ]; then
      echo "No Godot editors found in $editors_dir" >&2
      exit 1
    fi
    local latest_version="${installed_editors[-1]}"
    editor_path=$(find_editor_by_version "$latest_version") || exit 1
    echo "Running latest editor: $latest_version"
    "$editor_path" &
  else
    editor_path=$(find_editor_by_version "$search_version") || exit 1
    echo "Running editor: $editor_path"
    "$editor_path" &
  fi
}

delete_editor() {
  local search_version="$_arg_delete"
  local editor_path

  editor_path=$(find_editor_by_version "$search_version") || exit 1

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

  check_online_dependencies

  if ! command -v unzip &> /dev/null; then
    echo "Error: unzip is not installed." >&2
    exit 1
  fi

  fetch_releases

  local tag
  tag=$(resolve_version "$version") || exit 1

  local asset_suffix=""
  if [ "$mono" = "on" ]; then
    asset_suffix="_mono"
  fi

  local zip_name="Godot_v${tag}${asset_suffix}_linux.x86_64.zip"
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

  rm -rf "$tmp_dir"
  echo "Installed Godot $tag to $editors_dir"
}

# --- Main ---
parse_args "$@"

if [ "$_arg_list" = "on" ]; then
  list_installed_editors
elif [ "$_arg_run_set" = 1 ]; then
  run_editor
elif [ -n "$_arg_install" ]; then
  install_editor
elif [ -n "$_arg_delete" ]; then
  delete_editor
fi
