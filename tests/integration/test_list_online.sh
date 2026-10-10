#!/usr/bin/env bash
# integration/test_list_online.sh — `gim list -o` / `-oe` against the curl
# shim: stable map, experimental filter, MAX_ONLINE_VERSIONS cap, HTTP errors.

function test_list_online_stable() {
  run_gim list -o
  assert_exit_code 0 "list -o exits 0"
  assert_stderr_contains "Fetching online releases" "progress log on stderr"
  assert_stdout_contains "4.3.0-stable" "latest stable shown"
  assert_stdout_contains "4.2.2-stable" "latest patch of 4.2 shown"
}

function test_list_online_excludes_prerelease_by_default() {
  run_gim list -o
  assert_not_contains "$GIM_STDOUT" "dev" "no experimental tags without -e"
  assert_not_contains "$GIM_STDOUT" "rc" "no release candidates without -e"
}

function test_list_online_experimental() {
  run_gim list -oe
  assert_exit_code 0 "list -oe exits 0"
  assert_stdout_contains "4.4-dev7" "experimental tag shown with -e"
}

function test_list_online_respects_max_cap() {
  # Fixture has 6 distinct stable major.minor keys (3.5,3.6,4.0,4.1,4.2,4.3);
  # MAX_ONLINE_VERSIONS=5 must cap output at 5 lines.
  run_gim list -o
  local lines
  lines=$(printf '%s\n' "$GIM_STDOUT" | grep -c .)
  assert_equals "5" "$lines" "output capped at MAX_ONLINE_VERSIONS (5)"
}

function test_list_online_rate_limited() {
  export MOCK_HTTP_CODE=403
  run_gim list -o
  assert_exit_code 1 "HTTP 403 exits 1"
  assert_stderr_contains "GitHub API rate limit exceeded" "rate-limit error on stderr"
}

function test_list_online_fetch_error() {
  export MOCK_HTTP_CODE=000
  run_gim list -o
  assert_exit_code 1 "HTTP 000 exits 1"
  assert_stderr_contains "Failed to fetch releases from GitHub (HTTP 000)" "fetch error on stderr"
}

function test_list_online_zero_network_on_cache_hit() {
  # Phase 6: the second call must be served from cache with zero API calls.
  mocks_reset_calls
  run_gim list -o
  assert_exit_code 0 "first call succeeds"
  local first_count
  first_count=$(api_call_count)
  assert_equals "1" "$first_count" "first call made exactly one API request"

  run_gim list -o
  assert_exit_code 0 "second call succeeds"
  local second_count
  second_count=$(api_call_count)
  assert_equals "1" "$second_count" "second call made zero additional API requests (cache hit)"
}
