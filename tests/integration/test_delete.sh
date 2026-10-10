#!/usr/bin/env bash
# integration/test_delete.sh — delete_editor: confirmation, abort, multi-match
# selection, and sorted selection order.

function test_delete_confirmed() {
  make_fake_editor "4.2.1-stable" >/dev/null
  run_gim_stdin "y
" delete 4.2
  assert_exit_code 0 "confirmed delete exits 0"
  assert_stderr_contains "Deleted" "reports deletion"
  assert_dir_not_exists "$GIM_TEST_EDITORS_DIR/Godot_v4.2.1-stable_linux.x86_64" "editor removed"
}

function test_delete_aborted() {
  make_fake_editor "4.2.1-stable" >/dev/null
  run_gim_stdin "N
" delete 4.2
  assert_exit_code 0 "aborted delete exits 0"
  assert_stderr_contains "Aborted" "reports abort"
  assert_dir_exists "$GIM_TEST_EDITORS_DIR/Godot_v4.2.1-stable_linux.x86_64" "editor kept on abort"
}

function test_delete_default_is_no() {
  # Empty input (just newline) must default to No and keep the editor.
  make_fake_editor "4.2.1-stable" >/dev/null
  run_gim_stdin "
" delete 4.2
  assert_exit_code 0 "default (empty) exits 0"
  assert_stderr_contains "Aborted" "empty input treated as abort"
  assert_dir_exists "$GIM_TEST_EDITORS_DIR/Godot_v4.2.1-stable_linux.x86_64" "editor kept on default"
}

function test_delete_no_match_errors() {
  run_gim_stdin "y
" delete 9.9
  assert_exit_code 1 "no match exits 1"
  assert_stderr_contains "No editor found matching version" "reports no match"
}

function test_delete_multi_match_selection() {
  # Two editors matching the 4.2 prefix: 4.2.1 and 4.2.2. Pick #1.
  make_fake_editor "4.2.1-stable" >/dev/null
  make_fake_editor "4.2.2-stable" >/dev/null
  run_gim_stdin "1
y
" delete 4.2
  assert_exit_code 0 "multi-match delete exits 0"
  assert_stderr_contains "Multiple editors found" "prompts for selection"
  # Selection list is sorted descending, so #1 is the newest (4.2.2).
  assert_dir_not_exists "$GIM_TEST_EDITORS_DIR/Godot_v4.2.2-stable_linux.x86_64" "newest (listed first) deleted"
  assert_dir_exists "$GIM_TEST_EDITORS_DIR/Godot_v4.2.1-stable_linux.x86_64" "other editor kept"
}

function test_delete_multi_match_invalid_then_valid() {
  make_fake_editor "4.2.1-stable" >/dev/null
  make_fake_editor "4.2.2-stable" >/dev/null
  run_gim_stdin "9
2
y
" delete 4.2
  assert_exit_code 0 "recovers from invalid choice"
  assert_stderr_contains "Invalid choice" "rejects out-of-range input"
  # #2 is the older build (4.2.1) after descending sort.
  assert_dir_not_exists "$GIM_TEST_EDITORS_DIR/Godot_v4.2.1-stable_linux.x86_64" "second choice deleted"
  assert_dir_exists "$GIM_TEST_EDITORS_DIR/Godot_v4.2.2-stable_linux.x86_64" "first choice kept"
}

function test_delete_selection_order_descending() {
  make_fake_editor "4.2.1-stable" >/dev/null
  make_fake_editor "4.2.2-stable" >/dev/null
  # Provide a valid choice (1) + confirm so the selection loop terminates.
  run_gim_stdin "1
y
" delete 4.2
  # The numbered list must show 4.2.2 before 4.2.1 (descending).
  local list
  list=$(printf '%s\n' "$GIM_STDERR" | grep -E '^[[:space:]]+[0-9]+\)' | tr -d ' ')
  local first second
  first=$(printf '%s\n' "$list" | sed -n '1p')
  second=$(printf '%s\n' "$list" | sed -n '2p')
  assert_contains "$first" "4.2.2" "first listed is newest"
  assert_contains "$second" "4.2.1" "second listed is older"
}
