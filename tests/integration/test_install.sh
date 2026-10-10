#!/usr/bin/env bash
# integration/test_install.sh — install_editor: URL naming, no-op when present,
# extraction layout, executable bit, and failure handling.
# NOTE: `gim install 4.2` resolves to the FIRST 4.2* tag in the fixture, which
# is 4.2.2-stable.

function test_install_standard_build() {
  run_gim install 4.2
  assert_exit_code 0 "install 4.2 exits 0"
  assert_stderr_contains "Installed Godot 4.2.2-stable" "reports installed tag"
  # Standard zip name uses a dot before arch: Godot_v<tag>_linux.x86_64.zip
  local zip_calls
  zip_calls=$(grep -c 'Godot_v4.2.2-stable_linux\.x86_64\.zip' "$MOCK_CURL_COUNT_FILE" || true)
  assert_equals "1" "$zip_calls" "downloaded the standard zip name"
  local exe="$GIM_TEST_EDITORS_DIR/Godot_v4.2.2-stable_linux.x86_64/Godot_v4.2.2-stable_linux.x86_64"
  assert_file_executable "$exe" "installed binary is executable"
}

function test_install_mono_build() {
  run_gim install 4.2 -m
  assert_exit_code 0 "install -m exits 0"
  # Mono zip name uses underscores: Godot_v<tag>_mono_linux_x86_64.zip
  local zip_calls
  zip_calls=$(grep -c 'Godot_v4.2.2-stable_mono_linux_x86_64\.zip' "$MOCK_CURL_COUNT_FILE" || true)
  assert_equals "1" "$zip_calls" "downloaded the mono zip name"
  assert_dir_exists "$GIM_TEST_EDITORS_DIR/Godot_v4.2.2-stable_mono_linux_x86_64" "mono dir extracted"
}

function test_install_single_file_wrapped_in_dir() {
  # Standard zips contain a bare binary; install must wrap it in a directory.
  run_gim install 4.2
  assert_dir_exists "$GIM_TEST_EDITORS_DIR/Godot_v4.2.2-stable_linux.x86_64" "binary wrapped in dir"
  local exe="$GIM_TEST_EDITORS_DIR/Godot_v4.2.2-stable_linux.x86_64/Godot_v4.2.2-stable_linux.x86_64"
  assert_file_exists "$exe" "binary sits inside the wrapper dir"
}

function test_install_already_installed_noop() {
  run_gim install 4.2
  assert_exit_code 0 "first install succeeds"
  mocks_reset_calls
  run_gim install 4.2
  assert_exit_code 0 "second install exits 0 (no-op)"
  assert_stderr_contains "already installed" "reports already installed"
  # The API lookup still runs before the installed-check, but no download URL
  # should be requested.
  local dl
  dl=$(grep -c 'godotengine/godot-builds/releases/download' "$MOCK_CURL_COUNT_FILE" || true)
  assert_equals "0" "$dl" "no download attempted when already installed"
}

function test_install_unzip_failure_cleans_up() {
  export MOCK_UNZIP_FAIL=1
  run_gim install 4.2
  assert_exit_code 1 "unzip failure exits 1"
  assert_stderr_contains "Failed to extract" "reports extraction failure"
  # No editor dir should remain after a failed extraction.
  local leftover
  leftover=$(find "$GIM_TEST_EDITORS_DIR" -maxdepth 1 -name 'Godot_v*' 2>/dev/null | grep -c . || true)
  assert_equals "0" "$leftover" "no editor dir left behind after unzip failure"
}

function test_install_download_failure() {
  export MOCK_DOWNLOAD_CODE=000
  run_gim install 4.2
  assert_exit_code 1 "download failure exits 1"
  assert_stderr_contains "Download failed" "reports download failure"
}
