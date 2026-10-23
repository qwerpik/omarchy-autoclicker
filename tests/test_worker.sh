#!/usr/bin/env bash
# Argument handling and failure paths of the worker; needs no running compositor.
set -uo pipefail
worker=${1:?usage: test_worker.sh path/to/autoclicker-worker}
failed=0

expect() {
  local want=$1; shift
  "$worker" "$@" >/dev/null 2>&1
  local got=$?
  if [[ $got == "$want" ]]; then echo "ok   exit $got: $*"
  else echo "FAIL exit $got (want $want): $*"; failed=1; fi
}

expect 2 --interval-ms 0
expect 2 --interval-ms 60001
expect 2 --interval-ms 5ms
expect 2 --button back
expect 2 --unknown
# Valid arguments but no compositor to talk to.
WAYLAND_DISPLAY=autoclicker-test-missing XDG_RUNTIME_DIR=$(mktemp -d) expect 1 --check --interval-ms 10 --button right

exit $failed
