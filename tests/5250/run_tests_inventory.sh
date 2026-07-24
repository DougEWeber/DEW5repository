#!/usr/bin/env bash
#
# Runs the INVMAINT/INVMNT (inventory maintenance) sanity test suite
# against the live IBM i system, in order (later tests depend on state
# left behind by earlier ones -- see .inventory_state, written by
# test_i1_add.exp and updated by test_i3_update.exp).
#
# Usage: ./run_tests_inventory.sh

set -uo pipefail
cd "$(dirname "$0")"
source ./run_suite_lib.sh

run_suite \
  test_i1_add.exp \
  test_i2_display.exp \
  test_i3_update.exp \
  test_i4_add_duplicate.exp \
  test_i5_add_invalid_vendor.exp \
  test_i6_list.exp \
  test_i7_sell.exp \
  test_i8_not_found.exp
