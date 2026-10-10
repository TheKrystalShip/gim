# GIM test suite

A lightweight, dependency-free Bash test harness modelled on KGSM's framework.
No bats / shellspec / external runner — just `bash`, `jq`, and a handful of
coreutils. The suite is effectively GIM's compiler: `gim.sh` is pure Bash, so
running this on every push is the primary correctness gate.

## Running

```bash
./tests/run.sh                       # everything (unit + integration)
./tests/run.sh unit                  # only unit tests
./tests/run.sh integration           # only integration tests
./tests/run.sh --pattern '*version*' # only test files matching a glob
./tests/run.sh --function version_gt # only tests whose name matches a regex
./tests/run.sh --list                # list discovered tests without running
```

Output is TAP v14 on stdout (machine-readable), human progress on stderr.
Exit code is `0` only if every test passed.

## How it works

For each test file the runner:

1. **Plans** — greps the file for `test_*` functions *before* sourcing it.
2. **Sandboxes** — creates a throwaway `$HOME`/`XDG_*` tree and prepends a `bin/`
   of shims (`curl`, `wget`, `unzip`) to `PATH`, so no test touches the real
   filesystem or network.
3. **Sources** `gim.sh` (safe — it has a main guard) then the test file.
4. **Runs hooks** — `setup_file` once, then `setup` / `test_*` / `teardown` per
   test, then `teardown_file`.
5. **Reconciles** — every planned function must produce a result. A test that
   calls `exit` (GIM helpers do) or records nothing is turned into an explicit
   `FAIL`, never a silent pass.
6. **Emits TAP** — one `ok`/`not ok` point per test function.

Each test body runs in its own subshell, so a bare `exit` inside a helper is
contained to that test.

## Writing a test

Copy `templates/test.template.sh`, rename to `test_<topic>.sh`, and drop it in
`unit/` or `integration/`. Test files only **define** functions — they are
sourced, not executed.

```bash
function test_something() {
  run_gim list -o
  assert_exit_code 0 "list -o succeeds"
  assert_stdout_contains "4.3.0-stable" "latest stable listed"
}
```

Every test must record at least one `PASS`/`FAIL`/`SKIP` (via an assertion or
`pass`/`fail`/`skip`), or it is reconciled into a failure.

## Helpers

- **`run_gim <args...>`** — run `gim.sh` as a subprocess; sets `GIM_STDOUT`,
  `GIM_STDERR`, `GIM_RC`.
- **`run_gim_stdin <input> <args...>`** — same, feeding `<input>` to stdin (for
  interactive prompts like delete's `y/N`).
- **`run_gim_eval <snippet>`** — source `gim.sh` in a subshell and run a
  snippet against it; sets the same globals. **Do not wrap in `$( )`** — it
  populates globals, it doesn't echo.
- **`make_fake_editor <version> [--mono]`** — install a fake Godot editor into
  the sandbox (its `--version` prints a realistic string; launches are logged
  to `$GIM_EDITOR_RUN_LOG`).
- **`mocks_reset_calls`**, **`curl_call_count`**, **`api_call_count`** — inspect
  how many times the `curl` shim was invoked (used to prove cache hits).

## Assertions

`assert_equals`, `assert_not_equals`, `assert_null`, `assert_not_null`,
`assert_contains`, `assert_not_contains`, `assert_matches`,
`assert_file_exists`, `assert_file_not_exists`, `assert_dir_exists`,
`assert_dir_not_exists`, `assert_file_executable`, `assert_command_succeeds`,
`assert_command_fails`, `assert_exit_code`, `assert_stdout_only`,
`assert_stdout_contains`, `assert_stderr_contains`, `assert_stderr_empty`.

`assert_stdout_only` / `assert_stderr_*` encode GIM's documented routing
invariant (`CLAUDE.md`): stdout carries machine-readable data, stderr carries
logs and errors.

## Mocks

`tests/mocks/{curl,wget,unzip}` are shims installed into the sandbox `PATH`.
They read:

| Env var | Meaning |
|---|---|
| `MOCK_HTTP_CODE` | HTTP code the API shim reports (default `200`) |
| `MOCK_DOWNLOAD_CODE` | HTTP code the download shim reports (default `200`) |
| `MOCK_HTTP_BODY` | File served as the GitHub API JSON body |
| `MOCK_CURL_SEQUENCE` | File whose lines are body-paths, one consumed per API call |
| `MOCK_UNZIP_FAIL` | `1` => unzip exits 1 |

`MOCK_CURL_SEQUENCE` supports multi-response scenarios such as the Option C
cache retry (first call misses, second call hits).

## Layout

```
tests/
├── run.sh                 # runner: discovery, sandbox, TAP, filters
├── config.test.ini        # GIM_TEST_TIMEOUT, GIM_TEST_VERBOSE, ...
├── framework/             # loader, common, logging, assert, sandbox, mocks, execution
├── mocks/                 # curl / wget / unzip shims
├── fixtures/              # canned API responses + make_fake_editor.sh
├── templates/             # test.template.sh
├── unit/                  # in-process helper tests
└── integration/           # end-to-end CLI tests (subprocess)
```
