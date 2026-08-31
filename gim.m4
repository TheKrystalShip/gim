#!/usr/bin/env bash

# ARG_HELP([GIM],
#     [Godot Installer Manager.\nManage multiple Godot editor versions.])
# ARG_VERSION([echo "gim 0.1.0"])
# ARG_OPTIONAL_SINGLE([list], [l], [Lists all local Godot editor versions])
# ARG_OPTIONAL_SINGLE([run-default], [r], [Launch the Godot editor set with --set-default. Fails if no editor is set.])
# ARG_OPTIONAL_SINGLE([set-default], , [Sets the default Godot Editor version using the version string from Godot --version])
# ARGBASH_GO

# [ <-- needed because of Argbash

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
    installed_editors+=("$file")
  done < <(find "$editors_dir" -maxdepth 1 -type f -iname "${editor_file_name_start}*" 2>/dev/null)
}

save_default_editor() {
  local version_string="$1"

  if [ -z "$version_string" ]; then
    echo "Error: No version string provided." >&2
    exit 1
  fi

  mkdir -p "$APP_CONFIG_DIR" || { echo "Error: Could not create config directory $APP_CONFIG_DIR" >&2; exit 1; }
  echo "$version_string" > "$DEFAULT_EDITOR_FILE" || { echo "Error: Could not write to $DEFAULT_EDITOR_FILE" >&2; exit 1; }
  echo "Default editor set to: $version_string"
}

get_default_editor() {
  if [ ! -f "$DEFAULT_EDITOR_FILE" ]; then
    echo "Error: No default editor set. Use --set-default <version> to set one." >&2
    exit 1
  fi

  local version_string
  version_string=$(<"$DEFAULT_EDITOR_FILE")

  if [ -z "$version_string" ]; then
    echo "Error: Default editor file is empty. Use --set-default <version> to set one." >&2
    exit 1
  fi

  echo "$version_string"
}

find_editor_by_version() {
  local search_version="$1"
  local editor_path=""

  while IFS= read -r file; do
    if echo "$file" | grep -qF "$search_version"; then
      editor_path="$file"
      break
    fi
  done < <(find "$editors_dir" -maxdepth 1 -type f -iname "${editor_file_name_start}*" 2>/dev/null)

  if [ -z "$editor_path" ]; then
    echo "Error: No editor found matching version '$search_version' in $editors_dir" >&2
    return 1
  fi

  if [ ! -x "$editor_path" ]; then
    echo "Error: Editor at '$editor_path' is not executable." >&2
    return 1
  fi

  echo "$editor_path"
}

# --- Argument Handling ---

if [ -n "$_arg_set_default" ]; then
  save_default_editor "$_arg_set_default"

elif [ "$_arg_run_default" = on ]; then
  default_version=$(get_default_editor) || exit 1
  editor_path=$(find_editor_by_version "$default_version") || exit 1
  exec "$editor_path"

elif [ "$_arg_list" = on ]; then
  find_installed_editors
  if [ ${#installed_editors[@]} -eq 0 ]; then
    echo "No Godot editors found in $editors_dir"
    echo "Place Godot editors inside this folder to start using GIM."
    exit 0
  fi
  echo "Installed editors:"
  for editor in "${installed_editors[@]}"; do
    echo "  $editor"
  done

else
  echo "GIM - Godot Installer Manager"
  echo "Use -h or --help for usage information."
fi

# ] <-- needed because of Argbash
