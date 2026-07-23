#!/usr/bin/env bash
#
# Shared runner logic for the .exp test suites in this directory. Source
# this and call run_suite with the list of test scripts to run, in
# order. Requires config.exp (see config.exp.template in the
# ibmi-5250-telnet skill) with HOST/PORT/USER/PASS/LIB filled in.

run_suite() {
  local tests=("$@")
  local results=()
  local failures=0

  for t in "${tests[@]}"; do
    echo "==> Running $t"
    local output
    output=$(./"$t" 2>&1)
    local status=$?
    if [ $status -eq 0 ]; then
      results+=("PASS  $t")
    else
      results+=("FAIL  $t")
      failures=$((failures + 1))
    fi
    # Show just the last few lines (the PASS:/FAIL: summary line and, on
    # failure, the screen dump) rather than the full raw ANSI transcript.
    echo "$output" | tail -20
    echo
  done

  echo "===================== Summary ====================="
  for r in "${results[@]}"; do
    echo "$r"
  done
  echo "====================================================="

  if [ $failures -gt 0 ]; then
    echo "$failures test(s) failed."
    return 1
  fi
  echo "All tests passed."
  return 0
}
