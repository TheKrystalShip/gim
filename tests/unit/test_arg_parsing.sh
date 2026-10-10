#!/usr/bin/env bash
# unit/test_arg_parsing.sh — parse_args: action, modifier decomposition,
# positional version capture, and validation errors.

function test_parse_args_sets_action() {
  run_gim_eval 'parse_args list; printf "%s" "$_action"'
  assert_equals "list" "$GIM_STDOUT" "list action captured"
}

function test_parse_args_combined_flags_decompose() {
  # list -oe must equal list -o -e
  run_gim_eval 'parse_args list -oe; printf "online=%s exp=%s" "$_arg_online" "$_arg_experimental"'
  assert_equals "online=on exp=on" "$GIM_STDOUT" "-oe decomposes to -o and -e"
}

function test_parse_args_separate_flags() {
  run_gim_eval 'parse_args list -o -e; printf "online=%s exp=%s" "$_arg_online" "$_arg_experimental"'
  assert_equals "online=on exp=on" "$GIM_STDOUT" "-o -e equivalent to -oe"
}

function test_parse_args_mono_flag() {
  run_gim_eval 'parse_args install 4.2 -m; printf "mono=%s ver=%s" "$_arg_mono" "$_arg_install"'
  assert_equals "mono=on ver=4.2" "$GIM_STDOUT" "-m sets mono and captures version"
}

function test_parse_args_run_positional() {
  run_gim_eval 'parse_args run 4.7; printf "%s" "$_arg_run"'
  assert_equals "4.7" "$GIM_STDOUT" "run captures positional version"
}

function test_parse_args_install_requires_version() {
  run_gim_eval 'parse_args install'
  assert_exit_code 1 "install without version exits 1"
  assert_stderr_contains "install requires a VERSION argument" "error on stderr"
}

function test_parse_args_delete_requires_version() {
  run_gim_eval 'parse_args delete'
  assert_exit_code 1 "delete without version exits 1"
  assert_stderr_contains "delete requires a VERSION argument" "error on stderr"
}

function test_parse_args_unknown_option() {
  run_gim_eval 'parse_args list -z'
  assert_exit_code 1 "unknown option exits 1"
  assert_stderr_contains "Unknown option '-z'" "unknown option message"
}
