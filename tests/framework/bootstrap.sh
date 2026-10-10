# framework/bootstrap.sh — one-stop loader for the test framework.
# Sourcing this file gives you: loader (paths + config + common + logging),
# assert, sandbox, mocks, execution.

# shellcheck source=loader.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/loader.sh"
__load_module assert sandbox mocks execution
