#!/usr/bin/env bash

#####
# Generates a rough report of files changed in the last month, and their test coverage
#
# This report could help people who like writing tests find recently changed regions of code that need tests.
#
# usage: From the root directory of the repository, run this script
# e.g: $ ./scripts/show_test_coverage_for_files_changed_in_last_month.sh
#####

#make cover directory if it does not exist, so we can place output in a folder excluded by .gitignore
mkdir -p ./cover/

git diff HEAD '@{last month}' --name-only > ./cover/files_changed_in_last_month.txt

# append an additional search string that aligns with the coverage header
# so the header is also emitted and highlighted
echo "LINES RELEVANT   MISSED" >> ./cover/files_changed_in_last_month.txt

mix test --exclude needs_attention --cover > ./cover/test_coverage_by_file.txt

#grep matches the two files and emits only test coverage information about recently changed files, sorted by coverage percent
grep -F -f ./cover/files_changed_in_last_month.txt ./cover/test_coverage_by_file.txt | grep -A999 "LINES RELEVANT   MISSED" | sort -g
