#!/usr/bin/env bash
#
# Runs every 5250 sanity suite in this directory (vendor, then
# customer) and exits non-zero if either fails.
#
# Usage: ./run_all.sh

set -uo pipefail
cd "$(dirname "$0")"

overall=0

echo "########## Vendor maintenance (VNDMAINT) ##########"
./run_tests_vendor.sh
[ $? -eq 0 ] || overall=1

echo
echo "########## Customer maintenance (CUSTMAINT) ##########"
./run_tests_customer.sh
[ $? -eq 0 ] || overall=1

exit $overall
