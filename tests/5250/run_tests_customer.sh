#!/usr/bin/env bash
#
# Runs the CUSTMAINT/CUSMNT (customer maintenance) sanity test suite
# against the live IBM i system, in order (later tests depend on state
# left behind by earlier ones -- see .customer_state, written by
# test_c1_add.exp and consumed through test_c5_delete.exp, which
# deletes it).
#
# Usage: ./run_tests_customer.sh

set -uo pipefail
cd "$(dirname "$0")"
source ./run_suite_lib.sh

run_suite \
  test_c1_add.exp \
  test_c2_display.exp \
  test_c3_update.exp \
  test_c4_add_duplicate.exp \
  test_c5_delete.exp \
  test_c6_not_found.exp
