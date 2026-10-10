#!/usr/bin/env bash
# tests/unit/test_TEMPLATE.sh — copy this file, rename to test_<topic>.sh.
#
# Test files are sourced by run.sh, which has already loaded the framework
# (bootstrap.sh) and sourceed gim.sh in the parent process. You get:
#   - assertions: assert_equals, assert_contains, assert_file_exists, ...
#   - result primitives: pass, fail, skip, todo, bail_out
#   - sandbox env: $editors_dir, $GIM_TEST_EDITORS_DIR point into a throwaway dir
#   - mocks: curl/wget/unzip are shims; make_fake_editor <ver> [--mono]
#   - run_gim <args...> / run_gim_eval "<snippet>" set GIM_STDOUT/GIM_STDERR/GIM_RC
#
# Lifecycle hooks (all optional):
#   setup_file    — once, before any test in this file
#   setup         — before EACH test
#   teardown      — after EACH test
#   teardown_file — once, after all tests
#
# IMPORTANT: each test body runs in its own subshell, and GIM helpers call
# `exit` — so that's contained. But do NOT rely on state leaking between tests;
# use `setup` to reset. Every test must record at least one PASS/FAIL/SKIP or
# it is reconciled into a failure.

function setup() {
  # Reset state before each test (called in the test's subshell).
  :
}

function test_example_addition() {
  local result=$((2 + 2))
  assert_equals 4 "$result" "2+2 should equal 4"
}

function test_example_contains() {
  assert_contains "Godot Installation Manager" "Godot" "help mentions Godot"
}
