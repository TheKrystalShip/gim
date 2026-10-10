#!/usr/bin/env bash
# unit/test_editor_pattern.sh — build_editor_pattern + collect_editor_dirs
# NOTE: run_gim_eval populates the GIM_STDOUT global; do NOT wrap it in $( ).

function test_pattern_two_component_standard() {
  run_gim_eval 'build_editor_pattern 4.2 off'
  assert_equals "Godot_v4.2*_linux*" "$GIM_STDOUT" "4.2 standard -> *_linux*"
}

function test_pattern_two_component_mono() {
  run_gim_eval 'build_editor_pattern 4.2 on'
  assert_equals "Godot_v4.2*_mono*" "$GIM_STDOUT" "4.2 mono -> *_mono*"
}

function test_pattern_three_component_standard() {
  run_gim_eval 'build_editor_pattern 4.2.1 off'
  assert_equals "Godot_v4.2.1*_linux*" "$GIM_STDOUT" "4.2.1 standard keeps patch"
}

function test_pattern_prerelease_dash_to_charclass() {
  # Release tags use a dash (4.8-dev7) but --version output uses a dot
  # (4.8.dev7). The pattern must match both via a [-.] character class.
  run_gim_eval 'build_editor_pattern 4.8-dev7 off'
  assert_equals "Godot_v4.8[-.]dev7*_linux*" "$GIM_STDOUT" "4.8-dev7 -> [-.] class"
}

function test_pattern_numeric_patch_is_not_charclass() {
  run_gim_eval 'build_editor_pattern 4.3.0 off'
  assert_equals "Godot_v4.3.0*_linux*" "$GIM_STDOUT" "numeric patch stays literal"
}

function test_collect_dirs_excludes_mono_from_standard() {
  # *_linux* also appears inside mono dir names, so a standard search must
  # filter mono builds out (gim.sh:183-187).
  make_fake_editor "4.2.1-stable" >/dev/null
  make_fake_editor "4.2.1-stable" --mono >/dev/null
  run_gim_eval 'p=$(build_editor_pattern 4.2 off); collect_editor_dirs "$p" off'
  assert_contains "$GIM_STDOUT" "Godot_v4.2.1-stable_linux.x86_64" "standard dir collected"
  assert_not_contains "$GIM_STDOUT" "_mono_" "mono dir excluded from standard search"
}

function test_collect_dirs_returns_mono_when_mono_on() {
  make_fake_editor "4.2.1-stable" >/dev/null
  make_fake_editor "4.2.1-stable" --mono >/dev/null
  run_gim_eval 'p=$(build_editor_pattern 4.2 on); collect_editor_dirs "$p" on'
  assert_contains "$GIM_STDOUT" "_mono_" "mono dir collected when mono on"
  assert_not_contains "$GIM_STDOUT" "linux.x86_64" "standard dir excluded from mono search"
}
