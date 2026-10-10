# framework/sandbox.sh — per-file isolation via XDG + PATH redirection
# GIM already reads XDG_CONFIG_HOME / XDG_DATA_HOME / XDG_CACHE_HOME
# (gim.sh:20-25), so pointing them at a throwaway directory isolates every test
# with zero changes to gim.sh.

# create_sandbox — build an isolated tree and export env pointing into it.
create_sandbox() {
  SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/gim-test-sandbox.XXXXXX")" || bail_out "mktemp failed"
  export SANDBOX

  mkdir -p "$SANDBOX/.config" \
           "$SANDBOX/.local/share/gim/editors" \
           "$SANDBOX/.cache/gim" \
           "$SANDBOX/bin"

  export XDG_CONFIG_HOME="$SANDBOX/.config"
  export XDG_DATA_HOME="$SANDBOX/.local/share"
  export XDG_CACHE_HOME="$SANDBOX/.cache"
  export HOME="$SANDBOX"                       # belt-and-braces for any $HOME fallback

  # Canonical editors dir for fixtures (mirrors gim.sh:23-25).
  export GIM_TEST_EDITORS_DIR="$XDG_DATA_HOME/gim/editors"

  # Prepend the shim bin dir. Keep the real PATH behind it so jq/sed/etc still resolve.
  export PATH="$SANDBOX/bin:$PATH"

  log_debug "sandbox at $SANDBOX"
}

# reset_gim_state — clear per-test mutable state (installed editors, cache,
# fake-editor run log) so tests sharing a file-level sandbox stay hermetic.
# Called automatically before each test_* by the runner.
reset_gim_state() {
  rm -rf "${GIM_TEST_EDITORS_DIR:?}"/*
  rm -rf "${XDG_CACHE_HOME:?}/gim"/*
  : > "${GIM_EDITOR_RUN_LOG:-/dev/null}"
  mocks_reset_calls
}

# destroy_sandbox — remove the tree (idempotent).
destroy_sandbox() {
  if [ -n "${SANDBOX:-}" ] && [ -d "$SANDBOX" ]; then
    rm -rf "$SANDBOX"
  fi
}
