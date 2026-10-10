#!/usr/bin/env bash
# unit/test_find_editors.sh — find_editor_by_version, is_version_installed,
# resolve_editor_with_fallback (mono<->standard fallback + its messages)
# NOTE: run_gim_eval populates the GIM_STDOUT global; do NOT wrap it in $( ).

function test_is_version_installed_true() {
  make_fake_editor "4.2.1-stable" >/dev/null
  run_gim_eval 'is_version_installed 4.2.1 off'
  assert_exit_code 0 "4.2.1 standard detected as installed"
}

function test_is_version_installed_false() {
  run_gim_eval 'is_version_installed 9.9 off'
  assert_exit_code 1 "9.9 not installed"
}

function test_find_editor_by_version_returns_dir() {
  local created
  created=$(make_fake_editor "4.2.1-stable")
  run_gim_eval 'find_editor_by_version 4.2.1 off'
  assert_equals "$created" "$GIM_STDOUT" "find returns the editor directory"
}

function test_find_editor_by_version_miss_errors() {
  run_gim_eval 'find_editor_by_version 9.9 off'
  assert_exit_code 1 "miss returns 1"
  assert_stderr_contains "No editor found matching version" "miss reports error on stderr"
}

function test_fallback_standard_to_mono() {
  # Only a mono build installed; a standard search should fall back and say so.
  make_fake_editor "4.5.0-stable" --mono >/dev/null
  run_gim_eval 'resolve_editor_with_fallback 4.5 off'
  assert_contains "$GIM_STDOUT" "_mono_" "fell back to mono dir"
  assert_stderr_contains "Standard build not found for 4.5, using mono build." "fallback message on stderr"
}

function test_fallback_mono_to_standard() {
  make_fake_editor "4.5.0-stable" >/dev/null
  run_gim_eval 'resolve_editor_with_fallback 4.5 on'
  assert_not_contains "$GIM_STDOUT" "_mono_" "fell back to standard dir"
  assert_stderr_contains "Mono build not found for 4.5, using standard build." "fallback message on stderr"
}

function test_fallback_nothing_installed_fails() {
  run_gim_eval 'resolve_editor_with_fallback 4.5 off >/dev/null 2>&1'
  assert_exit_code 1 "no editor anywhere -> exit 1"
}
