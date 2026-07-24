#!/usr/bin/env bash
#
# Runs the order-entry (ORDENTR/ORDVIEW/ORDSTAT) sanity test suite
# against the live IBM i system. Unlike the vendor/customer/inventory
# suites, these tests are independent of each other (test_o1 writes
# .order_state for test_o2/test_o3 to reuse its order, but test_o4 and
# test_o5 create their own fresh customer/item and don't depend on
# .order_state) -- test_o1 must still run first since o2/o3 need it.
#
# Usage: ./run_tests_order.sh

set -uo pipefail
cd "$(dirname "$0")"
source ./run_suite_lib.sh

run_suite \
  test_o1_entry_accept.exp \
  test_o2_view.exp \
  test_o3_state_change.exp \
  test_o4_cancel_restores_qty.exp \
  test_o5_entry_abandon.exp
