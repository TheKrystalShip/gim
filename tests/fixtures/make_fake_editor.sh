#!/usr/bin/env bash
# fixtures/make_fake_editor.sh — emit a fake Godot editor install into the
# sandbox editors dir. Usage:
#   make_fake_editor.sh <version> [--mono]
# e.g.
#   make_fake_editor.sh 4.2.1-stable
#   make_fake_editor.sh 4.3.0-beta1 --mono
#
# Mirrors the on-disk layout gim.sh expects:
#   standard: <editors_dir>/Godot_v<ver>_linux.x86_64/Godot_v<ver>_linux.x86_64
#   mono:     <editors_dir>/Godot_v<ver>_mono_linux_x86_64/Godot_v<ver>_mono_linux.x86_64
#
# The binary answers --version with a realistic string (mono builds contain
# ".mono.", which run_editor uses for auto-detection) and appends its argv to
# $GIM_EDITOR_RUN_LOG when launched, so run tests can assert invocations.

set -uo pipefail

version="${1:?usage: make_fake_editor.sh <version> [--mono]}"
mono="${2:-}"
editors_dir="${GIM_TEST_EDITORS_DIR:?GIM_TEST_EDITORS_DIR must be set}"

if [ "$mono" = "--mono" ]; then
  dir_name="Godot_v${version}_mono_linux_x86_64"
  bin_name="Godot_v${version}_mono_linux.x86_64"
  vstr="${version//-/.}.mono.official.mock"
else
  dir_name="Godot_v${version}_linux.x86_64"
  bin_name="Godot_v${version}_linux.x86_64"
  vstr="${version//-/.}.official.mock"
fi

mkdir -p "$editors_dir/$dir_name"
cat > "$editors_dir/$dir_name/$bin_name" <<EOF
#!/usr/bin/env bash
if [ "\${1:-}" = "--version" ]; then
  echo "$vstr"
  exit 0
fi
if [ -n "\${GIM_EDITOR_RUN_LOG:-}" ]; then
  printf '%s %s\n' "\$0" "\$*" >> "\$GIM_EDITOR_RUN_LOG"
fi
exit 0
EOF
chmod +x "$editors_dir/$dir_name/$bin_name"

echo "$editors_dir/$dir_name"
