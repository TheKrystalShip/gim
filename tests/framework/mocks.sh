# framework/mocks.sh — shims for curl / wget / unzip + fake-editor factory
#
# Every external touchpoint of gim.sh is replaced with a controllable shim
# placed at the front of PATH, so no test ever reaches the network, unzips a
# real archive, or launches a real Godot binary.
#
# Env contract (read by the shims):
#   MOCK_HTTP_CODE        HTTP code the *API* curl/wget shim reports (default 200)
#   MOCK_DOWNLOAD_CODE    HTTP code the *download* shim reports (default 200)
#   MOCK_HTTP_BODY        File served as the GitHub API JSON body
#   MOCK_CURL_SEQUENCE    File whose lines are body-paths, one consumed per API call
#   MOCK_CURL_COUNT_FILE  File to append one line per curl call (for call counting)
#   MOCK_UNZIP_FAIL       "1" => unzip shim exits 1

MOCKS_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/../mocks" && pwd)"

# mocks_install — copy shims into the sandbox bin and seed defaults.
mocks_install() {
  local s
  for s in curl wget unzip; do
    install -m 0755 "$MOCKS_SRC/$s" "$SANDBOX/bin/$s" || bail_out "failed to install $s shim"
  done

  export MOCK_HTTP_CODE="${MOCK_HTTP_CODE:-200}"
  export MOCK_DOWNLOAD_CODE="${MOCK_DOWNLOAD_CODE:-200}"
  export MOCK_HTTP_BODY="${MOCK_HTTP_BODY:-$GIM_TEST_FIXTURES/releases.json}"
  export MOCK_CURL_COUNT_FILE="${MOCK_CURL_COUNT_FILE:-$SANDBOX/curl_calls.log}"
  export MOCK_UNZIP_COUNT_FILE="${MOCK_UNZIP_COUNT_FILE:-$SANDBOX/unzip_calls.log}"
  : > "$MOCK_CURL_COUNT_FILE"
  : > "$MOCK_UNZIP_COUNT_FILE"

  # Where the fake editor records its argv when launched (run tests).
  export GIM_EDITOR_RUN_LOG="${GIM_EDITOR_RUN_LOG:-$SANDBOX/editor_runs.log}"
  : > "$GIM_EDITOR_RUN_LOG"
}

# Reset the call counters (call at the start of a test that asserts on them).
mocks_reset_calls() {
  : > "${MOCK_CURL_COUNT_FILE:-/dev/null}"
  : > "${MOCK_UNZIP_COUNT_FILE:-/dev/null}"
}

# curl_call_count — number of curl invocations recorded so far.
curl_call_count() {
  if [ -n "${MOCK_CURL_COUNT_FILE:-}" ] && [ -f "$MOCK_CURL_COUNT_FILE" ]; then
    grep -c . "$MOCK_CURL_COUNT_FILE" 2>/dev/null || echo 0
  else
    echo 0
  fi
}

# api_call_count — number of recorded curl calls that targeted api.github.com.
api_call_count() {
  if [ -n "${MOCK_CURL_COUNT_FILE:-}" ] && [ -f "$MOCK_CURL_COUNT_FILE" ]; then
    grep -c 'api\.github\.com' "$MOCK_CURL_COUNT_FILE" 2>/dev/null || echo 0
  else
    echo 0
  fi
}

# wait_for_editor_run [n] — poll the fake-editor run log until it has n lines
# (default 1) or a short timeout elapses. Needed because run_editor launches the
# binary in the BACKGROUND ("&"), so the invocation is recorded asynchronously.
wait_for_editor_run() {
  local want="${1:-1}" i
  for i in $(seq 1 50); do
    if [ -n "${GIM_EDITOR_RUN_LOG:-}" ] && [ "$(grep -c . "$GIM_EDITOR_RUN_LOG" 2>/dev/null || echo 0)" -ge "$want" ]; then
      return 0
    fi
    sleep 0.1
  done
  return 1
}

# make_fake_editor <version> [--mono] — create an installed editor directly in
# the sandbox editors dir. Prints the created directory path.
make_fake_editor() {
  "$GIM_TEST_FIXTURES/make_fake_editor.sh" "$@"
}
