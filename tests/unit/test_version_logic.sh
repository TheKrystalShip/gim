#!/usr/bin/env bash
# unit/test_version_logic.sh — version_gt, parse_version_key, build_stable_map

function test_version_gt_greater_major() {
  run_gim_eval 'version_gt 4.3 4.2'
  assert_exit_code 0 "4.3 > 4.2"
}

function test_version_gt_greater_minor() {
  run_gim_eval 'version_gt 4.2.1 4.2'
  assert_exit_code 0 "4.2.1 > 4.2"
}

function test_version_gt_equal() {
  run_gim_eval 'version_gt 4.2 4.2'
  assert_exit_code 1 "4.2 is not > 4.2"
}

function test_version_gt_ignores_suffix() {
  # -stable and -rc1 strip to the same numeric core -> not greater.
  run_gim_eval 'version_gt 4.3-stable 4.3-rc1'
  assert_exit_code 1 "suffix stripped, 4.3 == 4.3"
}

function test_version_gt_missing_patch_treated_zero() {
  run_gim_eval 'version_gt 4.2.1 4.2'
  assert_exit_code 0 "missing patch treated as 0"
}

function test_parse_version_key_three_component() {
  run_gim_eval 'parse_version_key 4.3.2-stable; printf "%s|%s" "$_pv_version" "$_pv_key"'
  assert_equals "4.3.2|4.3" "$GIM_STDOUT" "key is major.minor, version full"
}

function test_parse_version_key_two_component() {
  run_gim_eval 'parse_version_key 4.3-stable; printf "%s|%s" "$_pv_version" "$_pv_key"'
  assert_equals "4.3|4.3" "$GIM_STDOUT" "two-component tag still keys major.minor"
}

function test_build_stable_map_latest_patch_wins() {
  run_gim_eval '
    available_releases=("4.2.1-stable|false" "4.2.2-stable|false" "4.2-stable|false")
    declare -A m
    build_stable_map m
    printf "%s" "${m[4.2]}"
  '
  assert_equals "4.2.2-stable" "$GIM_STDOUT" "latest patch kept per major.minor"
}

function test_build_stable_map_skips_prerelease() {
  run_gim_eval '
    available_releases=("4.2.1-stable|false" "4.3-dev7|true")
    declare -A m
    build_stable_map m
    printf "4.2=%s 4.3=%s" "${m[4.2]:-none}" "${m[4.3]:-none}"
  '
  assert_equals "4.2=4.2.1-stable 4.3=none" "$GIM_STDOUT" "prerelease excluded from stable map"
}
