#!/usr/bin/env bash
# integration/test_list_local.sh — `gim list` over installed editors: sorting,
# empty state, and the stdout/stderr routing invariant (CLAUDE.md:28-35).

function test_list_empty_state() {
  run_gim list
  assert_exit_code 0 "empty list exits 0"
  # B3 fix: the message must say "Godot", not the old "Gdot" typo.
  assert_stderr_contains "No Godot editors installed" "empty-state message on stderr (Godot spelled correctly)"
  assert_stdout_empty "no version data on stdout when empty"
}

function test_list_single_editor() {
  make_fake_editor "4.2.1-stable" >/dev/null
  run_gim list
  assert_exit_code 0 "list exits 0"
  assert_stdout_contains "4.2.1.stable.official.mock" "version printed on stdout"
  assert_stderr_empty "no logs on stdout-only list"
}

function test_list_sorts_descending() {
  make_fake_editor "4.1.0-stable" >/dev/null
  make_fake_editor "4.3.0-stable" >/dev/null
  make_fake_editor "4.2.0-stable" >/dev/null
  run_gim list
  # stdout should be 4.3, 4.2, 4.1 in that order (sort -Vr).
  local first second third
  first=$(printf '%s\n' "$GIM_STDOUT" | sed -n '1p')
  second=$(printf '%s\n' "$GIM_STDOUT" | sed -n '2p')
  third=$(printf '%s\n' "$GIM_STDOUT" | sed -n '3p')
  assert_contains "$first" "4.3" "first line is 4.3 (latest)"
  assert_contains "$second" "4.2" "second line is 4.2"
  assert_contains "$third" "4.1" "third line is 4.1 (oldest)"
}

function test_list_stdout_stderr_invariant() {
  # Piping stdout must yield ONLY version lines — the count of stdout lines
  # equals the number of installed editors, and no log text leaks.
  make_fake_editor "4.2.1-stable" >/dev/null
  make_fake_editor "4.3.0-stable" >/dev/null
  run_gim list
  local lines
  lines=$(printf '%s\n' "$GIM_STDOUT" | grep -c .)
  assert_equals "2" "$lines" "stdout line count == installed editor count"
  assert_not_contains "$GIM_STDOUT" "Fetching" "no progress text on stdout"
  assert_not_contains "$GIM_STDOUT" "No Godot" "no empty-state text on stdout"
}
