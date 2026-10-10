#!/usr/bin/env bash
# integration/test_release_cache.sh — Phase 6: persistent release cache +
# Option C auto-retry on lookup miss.

# --- Cache freshness / format (unit-style, via run_gim_eval) ---------------

function test_cache_fresh_within_ttl() {
  run_gim_eval '
    mkdir -p "$APP_CACHE_DIR"
    now=$(date +%s)
    jq -n --argjson ts "$now" --slurpfile r "$GIM_TEST_FIXTURES/releases.json" \
      "{fetched_at: \$ts, releases: \$r[0]}" > "$RELEASES_CACHE_FILE"
    if cache_is_fresh; then echo fresh; else echo stale; fi
  '
  assert_equals "fresh" "$GIM_STDOUT" "cache within TTL is fresh"
}

function test_cache_stale_beyond_ttl() {
  run_gim_eval '
    mkdir -p "$APP_CACHE_DIR"
    old=$(( $(date +%s) - 7200 ))   # 2h ago, TTL is 1h
    jq -n --argjson ts "$old" --slurpfile r "$GIM_TEST_FIXTURES/releases.json" \
      "{fetched_at: \$ts, releases: \$r[0]}" > "$RELEASES_CACHE_FILE"
    if cache_is_fresh; then echo fresh; else echo stale; fi
  '
  assert_equals "stale" "$GIM_STDOUT" "cache beyond TTL is stale"
}

function test_cache_missing_timestamp_is_miss() {
  run_gim_eval '
    mkdir -p "$APP_CACHE_DIR"
    cp "$GIM_TEST_FIXTURES/releases.json" "$RELEASES_CACHE_FILE"   # no fetched_at
    if cache_is_fresh; then echo fresh; else echo miss; fi
  '
  assert_equals "miss" "$GIM_STDOUT" "cache without fetched_at is a miss"
}

function test_cache_malformed_json_is_miss() {
  run_gim_eval '
    mkdir -p "$APP_CACHE_DIR"
    echo "not json {" > "$RELEASES_CACHE_FILE"
    if cache_is_fresh; then echo fresh; else echo miss; fi
  '
  assert_equals "miss" "$GIM_STDOUT" "malformed cache is a miss, not fatal"
}

# --- Integration behaviour --------------------------------------------------

function test_second_list_uses_cache() {
  mocks_reset_calls
  run_gim list -o
  assert_exit_code 0 "first list -o succeeds"
  assert_equals "1" "$(api_call_count)" "first call hits the API once"

  run_gim list -o
  assert_exit_code 0 "second list -o succeeds"
  assert_stderr_contains "Using cached releases" "second call served from cache"
  assert_equals "1" "$(api_call_count)" "second call makes zero extra API requests"
}

function test_ttl_zero_forces_refetch() {
  export GIM_RELEASES_TTL=0
  mocks_reset_calls
  run_gim list -o
  run_gim list -o
  assert_equals "2" "$(api_call_count)" "TTL=0 forces a re-fetch every time"
}

function test_corrupt_cache_recovers() {
  mkdir -p "$APP_CACHE_DIR"
  echo "{{{{ corrupt" > "$RELEASES_CACHE_FILE"
  mocks_reset_calls
  run_gim list -o
  assert_exit_code 0 "corrupt cache does not break list -o"
  assert_equals "1" "$(api_call_count)" "recovers by refetching"
  assert_stdout_contains "4.3.0-stable" "releases still listed"
}

function test_cache_written_to_xdg_cache_home() {
  run_gim list -o
  assert_exit_code 0 "list -o succeeds"
  assert_file_exists "$XDG_CACHE_HOME/gim/releases.json" "cache written under XDG_CACHE_HOME"
  # Sanity: the sandbox HOME is isolated, so this is NOT the real user cache.
  assert_matches "$XDG_CACHE_HOME" "gim-test-sandbox" "cache stayed inside the sandbox"
}

function test_stale_cache_used_on_rate_limit() {
  # Seed a stale cache, then force a 403. gim should warn + use stale, not fail.
  run_gim_eval '
    mkdir -p "$APP_CACHE_DIR"
    old=$(( $(date +%s) - 7200 ))
    jq -n --argjson ts "$old" --slurpfile r "$GIM_TEST_FIXTURES/releases.json" \
      "{fetched_at: \$ts, releases: \$r[0]}" > "$RELEASES_CACHE_FILE"
  '
  export MOCK_HTTP_CODE=403
  run_gim list -o
  assert_exit_code 0 "stale cache turns a 403 into a warning, not a failure"
  assert_stderr_contains "using stale cached releases" "warns about stale fallback"
  assert_stdout_contains "4.3.0-stable" "still lists from stale cache"
}

function test_option_c_refetch_on_miss() {
  # Warm the cache with a list that LACKS 4.4, then ask for 4.4. The cached
  # miss must trigger an invalidate + single re-fetch that HAS 4.4.
  printf '%s\n%s\n' \
    "$GIM_TEST_FIXTURES/releases_no_44.json" \
    "$GIM_TEST_FIXTURES/releases_with_44.json" > "$SANDBOX/seq.txt"
  export MOCK_CURL_SEQUENCE="$SANDBOX/seq.txt"
  export MOCK_HTTP_BODY="$GIM_TEST_FIXTURES/releases_no_44.json"

  run_gim list -o                       # warms cache with the no-4.4 list
  assert_exit_code 0 "warm-up succeeds"
  assert_equals "1" "$(api_call_count)" "warm-up made one API call"

  run_gim install 4.4                   # cached miss -> re-fetch -> hit
  assert_exit_code 0 "install 4.4 succeeds after re-fetch"
  assert_stderr_contains "Installed Godot 4.4.0-stable" "installed the re-fetched version"
  assert_equals "2" "$(api_call_count)" "exactly two API calls (warm-up + retry)"
}
