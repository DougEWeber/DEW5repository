#!/usr/bin/env bash
#
# Runs the VNDMAINT (vendor maintenance) sanity test suite against the
# live IBM i system, in order (later tests depend on state left behind
# by earlier ones -- see .vendor_state, written by test_01_add.exp).
#
# Usage: ./run_tests_vendor.sh
# Requires config.exp in this directory (see config.exp.template in the
# ibmi-5250-telnet skill) with HOST/PORT/USER/PASS/LIB filled in.

set -uo pipefail
cd "$(dirname "$0")"
source ./run_suite_lib.sh

run_suite \
  test_01_add.exp \
  test_02_display.exp \
  test_03_update.exp \
  test_04_list.exp \
  test_05_not_found.exp
