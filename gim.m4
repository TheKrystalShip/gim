#!/usr/bin/env bash

# ARG_HELP([GIM - Godot Install Manager\nManage multiple Godot editor versions.\n])
# ARG_VERSION([echo "$NAME_SHORT $VERSION"])
# ARG_OPTIONAL_ACTION([list], l, [Lists all local Godot editor versions], [list_installed_editors])
# ARG_OPTIONAL_SINGLE([run], r, [Launch a specific Godot editor if a version is passed, otherwise runs the latest present. Fails if no editors are present], [run_default_editor])
# ARG_OPTIONAL_SINGLE([install], i, [Install a specific Godot editor version])
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

DEFAULT_EDITOR_FILE="$APP_CONFIG_DIR/default_editor"

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

# --- Parse Arguments (after helper functions are defined) ---
parse_commandline "$@"

# --- Argument Handling ---

if [ "$_arg_list" = on ]; then
  find_installed_editors
  if [ ${#installed_editors[@]} -eq 0 ]; then
    echo "No Godot editors found in $editors_dir"
    echo "Place Godot editors inside this folder to start using $NAME_SHORT."
    exit 0
  fi
  echo "Installed editors:"
  for editor in "${installed_editors[@]}"; do
    echo "  $editor"
  done

else
  echo "$NAME_SHORT - $NAME_LONG"
  echo "Use -h or --help for usage information."
fi

# ] <-- needed because of Argbash
