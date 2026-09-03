#!/usr/bin/env bash

# ARG_HELP([GIM - Godot Install Manager\nManage multiple Godot editor versions.\n])
# ARG_VERSION([echo "$NAME_SHORT $VERSION"])
# ARG_OPTIONAL_ACTION([list], l, [Lists all local Godot editor versions], [list_installed_editors])
# ARG_OPTIONAL_SINGLE([run], r, [Run a specific installed Godot Editor version. If called without a version, run the latest. Fails if the specific version is not present, or no versions are present])
# ARG_OPTIONAL_SINGLE([install], i, [Install a specific Godot editor version])
# ARG_OPTIONAL_SINGLE([delete], d, [Delete a specific installed Godot Editor. Fails if no match is found])
# ARGBASH_PREPARE

# [ <-- needed because of Argbash

# --- Constants ---
NAME_SHORT="GIM"
NAME_LONG="Godot Installation Manager"
VERSION="0.1.0"

# --- XDG Base Directory Setup ---
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"

APP_CONFIG_DIR="$XDG_CONFIG_HOME/gim"
APP_DATA_DIR="$XDG_DATA_HOME/gim"
editors_dir="$APP_DATA_DIR/editors/"
editor_file_name_start="Godot"



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
  find_installed_editors

  if [ ${#installed_editors[@]} -eq 0 ]; then
    echo "No Godot editors found in $editors_dir"
    echo "Place Godot editors inside this folder to start using $NAME_SHORT."
    exit 0
  fi
  for editor in "${installed_editors[@]}"; do
    echo "  $editor"
  done
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
  local zip_name="Godot_v${version}-stable_linux.x86_64.zip"
  local download_url="https://github.com/godotengine/godot-builds/releases/download/${version}-stable/${zip_name}"

  if ! command -v curl &> /dev/null && ! command -v wget &> /dev/null; then
    echo "Error: Neither curl nor wget is installed." >&2
    exit 1
  fi

  if ! command -v unzip &> /dev/null; then
    echo "Error: unzip is not installed." >&2
    exit 1
  fi

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

  mkdir -p "$editors_dir"
  mv "$tmp_dir"/Godot_v* "$editors_dir/"
  chmod +x "$editors_dir"/Godot_v*

  rm -rf "$tmp_dir"
  echo "Installed Godot $version to $editors_dir"
}

# --- Parse Arguments (after helper functions are defined) ---
parse_commandline "$@"

# --- Argument Handling ---

if [ "$_arg_list" = on ]; then
  list_installed_editors
elif [ -n "$_arg_run" ]; then
  run_editor
elif [ -n "$_arg_install" ]; then
  install_editor
elif [ -n "$_arg_delete" ]; then
  delete_editor
fi

# ] <-- needed because of Argbash
