# GIM Arguments

This document keeps track of all the arguments GIM accepts, and what they are used for.
___

-h --help
: Displays a helpful introduction and lists all commands

-l --list
: Lists all local Godot editor versions

-i --install `<version>`
: Download a specific Godot Editor version (e.g., "4.7", "4.7.2-stable", "4.8-dev4"). Searches GitHub releases for an exact match. If no exact match is found, shows available versions (latest stable for each major and the latest experimental) and exits.

-m --mono
: Download mono build instead of standard build. Only affects --install.

-o --online
: List latest online versions (latest stable for each major and the latest experimental). Requires network access.

-r --run `<version>` (default: latest)
: Run a specific installed Godot Editor version. If called without a version, run the latest. Fails if the specific version is not present, or no versions are present.

-d --delete `<version>`
: Delete a specific installed Godot Editor. Fails if no match is found.

-v --version
: Displays the current version of GIM
