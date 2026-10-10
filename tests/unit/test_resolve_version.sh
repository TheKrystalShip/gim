#!/usr/bin/env bash
# unit/test_resolve_version.sh — resolve_version matching + suggestion output

function test_resolve_version_exact_prefix() {
  run_gim_eval '
    available_releases=("4.2.1-stable|false" "4.3.0-stable|false")
    resolve_version 4.2
  '
  assert_exit_code 0 "prefix 4.2 resolves"
  assert_equals "4.2.1-stable" "$GIM_STDOUT" "echoes the full tag on stdout"
}

function test_resolve_version_full_tag() {
  run_gim_eval '
    available_releases=("4.2.1-stable|false" "4.3.0-stable|false")
    resolve_version 4.3.0-stable
  '
  assert_exit_code 0 "full tag resolves"
  assert_equals "4.3.0-stable" "$GIM_STDOUT" "full tag returned verbatim"
}

function test_resolve_version_miss_suggestions() {
  run_gim_eval '
    available_releases=("4.2.1-stable|false" "4.3.0-stable|false" "4.4-dev7|true")
    resolve_version 9.9
  '
  assert_exit_code 1 "miss returns 1"
  assert_stderr_contains "No exact match found. Available versions:" "header on stderr"
  assert_stderr_contains "4.2.1-stable" "suggests stable 4.2.1"
  assert_stderr_contains "4.4-dev7" "suggests latest experimental"
}

function test_resolve_version_suggestions_capped() {
  # MAX_SIMILAR_VERSIONS=5: provide 8 stable major.minor keys, expect <= 5
  # suggestion lines after the header.
  run_gim_eval '
    available_releases=(
      "3.5-stable|false" "3.6-stable|false" "4.0-stable|false" "4.1-stable|false"
      "4.2-stable|false" "4.3-stable|false" "4.4-stable|false" "4.5-stable|false"
    )
    resolve_version 9.9
  ' >/dev/null
  assert_exit_code 1 "still a miss"
  # Count numbered suggestion lines (two leading spaces) on stderr.
  local suggestions
  suggestions=$(printf '%s\n' "$GIM_STDERR" | grep -c '^  ')
  assert_equals "5" "$suggestions" "suggestions capped at MAX_SIMILAR_VERSIONS (5)"
}

function test_resolve_version_matches_before_experimental() {
  # A stable tag matching the prefix must win even if an experimental tag
  # shares the prefix (array order: stable first).
  run_gim_eval '
    available_releases=("4.2.1-stable|false" "4.2-rc1|true")
    resolve_version 4.2
  '
  assert_equals "4.2.1-stable" "$GIM_STDOUT" "stable preferred on prefix match"
}
