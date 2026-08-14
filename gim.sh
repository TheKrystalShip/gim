#!/usr/bin/bash

readonly version="0.1.0"

# ///// Function Definitions \\\\\

find_installed_editors () {
  # Find files inside $editors_dir starting with "$editor_file_name_start" (Godot)
  installed_editors=`find "$editors_dir" -type f -iname "$editor_file_name_start"*`

  # Check installed editors array is empty
  # if [ "${#installed_editors[@]}" -eq 0 ]; then
  #   # If so, inform and exit
  #   echo "WARNING: No Godot editors found inside $editors_dir. To use GIM, place editors inside this folder."
  # fi

}

show_intalled_editors () {
  # Get installed editors
  find_installed_editors

  # Print installed editors
  echo "Installed editors:"

  for ((i = 0 ; i <= ${#installed_editors[@]} ; i++)); do
    echo "${installed_editors[$i]}"
    # printf "[$i]: ${installed_editors[$i]}\n"
  done
}

# ///// Script Start \\\\\

# Check if XDG_DATA_HOME is set, otherwise use a default
if [ -z "$XDG_DATA_HOME" ]; then
 DATA_DIR="$HOME/.local/share"
else
  DATA_DIR="$XDG_DATA_HOME"
fi

APP_DATA_DIR="$DATA_DIR/gim"

# Check if application folder exists
if [ ! -d $APP_DATA_DIR ]; then
  echo "Application folder does not exist, creating..."

  # Create application-specific directory because it does not exist
  `mkdir -p $APP_DATA_DIR`

  # Check if creation of directory failed
  if [ $? -ne 0 ] ; then
      echo "Could not create $APP_DATA_DIR! Exiting..."
      exit 1
  fi

  echo "Created folder $APP_DATA_DIR"
fi

# Initialize remaining constants/variables
readonly editors_dir="$APP_DATA_DIR/editors/"
readonly editor_file_name_start="Godot"

# Check if the folder container editors exists
if [ ! -d $editors_dir ]; then
  # If it does not exist, initialize files and folders
  echo "Path $editors_dir does not exist, creating..."
  `mkdir -p $editors_dir`
  if [ $? -ne 0 ] ; then
      echo Failure
  fi

  # If directories are just initialized, inform about installation and exit
  echo "Place Godot editors inside $editors_dir to start using GIM"
  exit 0
fi




# Launch selected editor
# TODO: Implement

exit 0
