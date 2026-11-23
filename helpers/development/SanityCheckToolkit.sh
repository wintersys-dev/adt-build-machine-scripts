#!/bin/sh
#: Name:        lint_toolkit.sh
#: Purpose:     Comprehensive POSIX syntax, ShellCheck, security, and toolkit convention linter
#:              across all Wintersys Agile Deployment Toolkit repositories.
#: Author:      Peter Winter
#: Date:        23/11/2026
#: Version:     2.0
#:
#: Usage:       lint_toolkit.sh [target_directory]
#:              lint_toolkit.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Optional] Root directory containing toolkit repositories (defaults to current directory).
#:
#: Dependencies:
#:   - External binaries: awk, cat, cut, find, grep, mktemp, printf, rm, sed, sh, sort
#:   - Optional binary:   shellcheck
#:
#: Exit Codes:
#:   0          All scripts passed validation (warnings may still be displayed)
#:   1          One or more scripts failed validation checks
###################################################################################
# License Agreement:
# This file is part of The Wintersys Agile Deployment Toolkit.
# The Agile Deployment Toolkit is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# The Agile Deployment Toolkit is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# You should have received a copy of the GNU General Public License
# along with The Agile Deployment Toolkit.  If not, see <http://gnu.org>.
####################################################################################

if [ "${1}" = "-h" ] || [ "${1}" = "--help" ]
then
        grep '^#:' "$0" | cut -c 4-
        exit 0
fi

target_dir="${1:-.}"

if [ ! -d "${target_dir}" ]
then
        printf 'Error: Target directory does not exist: %s\n' "${target_dir}" >&2
        exit 1
fi

total_checked=0
total_failed=0
total_warnings=0

has_shellcheck=0
if command -v shellcheck >/dev/null 2>&1
then
        has_shellcheck=1
else
        printf 'Note: shellcheck is not installed; skipping static analysis pass.\n\n' >&2
fi

tmp_list="$(mktemp /tmp/toolkit_lint_list.XXXXXX)"
tmp_err="$(mktemp /tmp/toolkit_lint_err.XXXXXX)"
tmp_repo_stats="$(mktemp /tmp/toolkit_lint_repos.XXXXXX)"

cleanup() {
        rm -f "${tmp_list}" "${tmp_err}" "${tmp_repo_stats}"
}
trap cleanup EXIT INT TERM

# Exclude .git directories and lint_toolkit.sh itself, then collect all .sh scripts sorted cleanly
find "${target_dir}" -path '*/.git' -prune -o -type f -name '*.sh' ! -name 'lint_toolkit.sh' -print | sort > "${tmp_list}"

fail_msg() {
        printf '  [FAIL] %s\n' "${1}" >&2
        file_failed=1
}

warn_msg() {
        printf '  [WARN] %s\n' "${1}" >&2
        file_warned=$((file_warned + 1))
}
