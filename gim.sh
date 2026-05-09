#!/usr/bin/bash

editors_dir="editors/"
initial_run=false
editor_file_name="Godot"

# Check if editor folder exists
if [ ! -d $editors_dir ]; then
  # If not, create it
  initial_run=true
  echo "Folder $editors_dir does not exist, creating it."
  `mkdir $editors_dir`
fi

# If it's the first run, inform there are no installs present yet
if [ "$initial_run" -o ]; then
  echo "Place Godot editors inside $editors_dir to use GIM"
  exit 0
fi

# Find editors starting with "Godot"
installed_editors=`find . -name '$editor_file_name*'`

# Check installed editors array is empty
if [ "${#installed_editors[@]}" -eq 0]; then
  # If so, inform and exit
  echo "ERROR: No Godot editors found inside $editors_dir"
  exit 1
fi

# Print installed editors with index for user to select
echo -e "Select an editor to launch.\nInstalled editors:"

for ((i = 0 ; i <= ${#installed_editors[@]} ; i++)); do
  echo "[$i]\t${installed_editors[$i]}"
done

# Get index input from user
read index_input

# Parse input to integer number using regex
input_number='$index_input =~ ^[0-9]+$'

# Exit if input is not an integer number
if ! [[ $yournumber =~ $re ]] ; then
   echo "ERROR: Not a number"
   exit 1
fi

# Launch selected editor
# TODO: Implement

exit 0

# ///// For in the future \\\\\

# Check if default version is present
# If so, start it and exit
# Otherwise, inform and ask to either download it or select new default

# Bootstrap the environment.
# shellcheck disable=SC1091
# source "$(dirname "$(readlink -f "$0")")/lib/bootstrap.sh"

# Load essential modules early
# module_interactive=$(__find_module interactive.sh)

# installer_script="$(__find_or_fail installer.sh)"

# Check if installer script is present
# if [[ ! -f "$installer_script" ]]; then
#   __print_error "installer.sh missing, won't be able to check for updates"
#   __print_error "Installation might be compromised, please reinstall KGSM"
#   exit $EC_GENERAL
# fi

# Basic update functions
# function check_for_update() {
#   "$installer_script" --check-update
# }

# function update_script() {
#   "$installer_script" --update
# }

# function get_version() {
#   "$installer_script" --version
# }
