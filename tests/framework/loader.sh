# framework/loader.sh — environment detection + module loading
# Sets GIM_TEST_* paths, sources config, and provides __load_module.

__load_module() {
  local __mod_dir
  __mod_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local __name
  for __name in "$@"; do
    # shellcheck source=/dev/null
    source "$__mod_dir/${__name}.sh"
  done
}

# --- Locate the repo root and key paths -------------------------------------
FRAMEWORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GIM_TEST_TESTS_DIR="$(cd "$FRAMEWORK_DIR/.." && pwd)"
GIM_TEST_ROOT_DIR="$(cd "$GIM_TEST_TESTS_DIR/.." && pwd)"
export FRAMEWORK_DIR GIM_TEST_TESTS_DIR GIM_TEST_ROOT_DIR

GIM_SCRIPT="${GIM_SCRIPT:-$GIM_TEST_ROOT_DIR/gim.sh}"
export GIM_SCRIPT

GIM_TEST_FIXTURES="$GIM_TEST_TESTS_DIR/fixtures"
export GIM_TEST_FIXTURES

# --- Load optional config (KEY=value .ini sourced as bash) ------------------
GIM_TEST_CONFIG="${GIM_TEST_CONFIG:-$GIM_TEST_TESTS_DIR/config.test.ini}"
if [ -f "$GIM_TEST_CONFIG" ]; then
  # shellcheck source=/dev/null
  source "$GIM_TEST_CONFIG"
fi

__load_module common logging
