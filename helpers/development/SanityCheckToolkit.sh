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

/bin/echo 'run this first find . -path ./.git -prune -o -type d -exec chmod 755 {} + -o -type f -name "*.sh" -exec chmod 755 {} + -o -type f -exec chmod 644 {} +'
exit

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

while IFS= read -r script
do
        total_checked=$((total_checked + 1))
        file_failed=0
        file_warned=0

        # Derive top-level repository / subdirectory name relative to target_dir
        rel_path="${script#"${target_dir%/}/"}"
        case "${rel_path}" in
                */*) repo_name="${rel_path%%/*}" ;;
                *)   repo_name="(root)" ;;
        esac

        # Collect messages in a buffer so we only print the file header if issues exist
        : > "${tmp_err}"

        {
                # -----------------------------------------------------------------
                # 1. Shebang & Line Endings
                # -----------------------------------------------------------------
                first_line="$(sed -n '1p' "${script}")"
                if [ "${first_line}" != "#!/bin/sh" ]
                then
                        fail_msg "Invalid or missing POSIX shebang on line 1 (got: '${first_line}', expected '#!/bin/sh')"
                fi

                if grep -q "$(printf '\r')" "${script}"
                then
                        fail_msg "Contains Windows CRLF (\\r) line endings"
                fi

                # -----------------------------------------------------------------
                # 2. POSIX /bin/sh Syntax Check
                # -----------------------------------------------------------------
                if ! /bin/sh -n "${script}" 2>/tmp/sh_syntax.$$
                then
                        fail_msg "POSIX syntax error:"
                        sed 's/^/         /' /tmp/sh_syntax.$$ >&2
                fi
                rm -f /tmp/sh_syntax.$$

                # -----------------------------------------------------------------
                # 3. ShellCheck Static Analysis (if installed)
                # -----------------------------------------------------------------
                if [ "${has_shellcheck}" -eq 1 ]
                then
                        # Exclude SC1090/SC1091 (dynamic sourcing of HOME/BUILD_HOME helpers)
                        if ! shellcheck -s sh -S warning -e SC1090,SC1091 "${script}" >/tmp/sc_out.$$ 2>&1
                        then
                                fail_msg "ShellCheck findings:"
                                sed 's/^/         /' /tmp/sc_out.$$ >&2
                        fi
                        rm -f /tmp/sc_out.$$
                fi

                # -----------------------------------------------------------------
                # 4. Toolkit Context Drift: BUILD_HOME vs HOME Helper Mismatches
                # -----------------------------------------------------------------
                if grep -q 'BUILD_HOME' "${script}" && grep -q 'ExtractConfigValue\.sh' "${script}"
                then
                        fail_msg "Uses BUILD_HOME but calls ExtractConfigValue.sh (expected GetVariableValue.sh)"
                fi

                if grep -q '/home/homedir\.dat' "${script}" && grep -q 'GetVariableValue\.sh' "${script}"
                then
                        fail_msg "Uses /home/homedir.dat (HOME) but calls GetVariableValue.sh (expected ExtractConfigValue.sh)"
                fi

                if grep -q '/home/buildhome\.dat' "${script}" && grep -q '/home/homedir\.dat' "${script}"
                then
                        warn_msg "References both /home/buildhome.dat and /home/homedir.dat in the same script"
                fi

                # -----------------------------------------------------------------
                # 5. Variable Naming Drift (Build-Host vs Runtime Conventions)
                # -----------------------------------------------------------------
                if grep -q 'ExtractConfigValue\.sh' "${script}" && grep -qE "ExtractConfigValue\.sh['\"[:space:]]+APPLICATION_REPOSITORY_" "${script}"
                then
                        fail_msg "Runtime script queries underscored APPLICATION_REPOSITORY_* key via ExtractConfigValue.sh"
                fi

                if grep -q 'GetVariableValue\.sh' "${script}" && grep -qE "GetVariableValue\.sh['\"[:space:]]+APPLICATIONREPOSITORY" "${script}"
                then
                        fail_msg "Build script queries non-underscored APPLICATIONREPOSITORY* key via GetVariableValue.sh"
                fi

                # -----------------------------------------------------------------
                # 6. Credential & Secret Exposure Checks
                # -----------------------------------------------------------------
                if grep -E 'curl.*(-H|--header)[[:space:]]+["'\'']?(PRIVATE-TOKEN|Authorization):' "${script}" >/dev/null 2>&1
                then
                        fail_msg "Credential exposed in curl CLI arguments (pass via stdin -H @- instead)"
                fi

                if grep -E 'curl.*(-u|--user)[[:space:]]+' "${script}" >/dev/null 2>&1
                then
                        fail_msg "Credentials exposed via curl -u/--user CLI flag (pass via stdin -K - instead)"
                fi

                if grep -q 'REPOSITORY_TOKEN=' "${script}" && ! grep -q 'unset.*REPOSITORY_TOKEN' "${script}"
                then
                        warn_msg "REPOSITORY_TOKEN is set but never explicitly unset"
                fi
                # -----------------------------------------------------------------
                # 7. Temp File & Cleanup Hygiene
                # -----------------------------------------------------------------
                if grep -q 'mktemp' "${script}" && ! grep -q 'trap ' "${script}"
                then
                        fail_msg "Uses mktemp without a trap cleanup handler"
                fi

                # -----------------------------------------------------------------
                # 8. Curl Network Reliability Checks
                # -----------------------------------------------------------------
                if grep -q 'curl ' "${script}" && ! grep -q -- '--connect-timeout' "${script}"
                then
                        warn_msg "Calls curl without --connect-timeout (risk of hanging indefinitely)"
                fi

                # -----------------------------------------------------------------
                # 9. POSIX Exit Code Range Check (> 255 wraps modulo 256)
                # -----------------------------------------------------------------
                if grep -E '^[[:space:]]*exit[[:space:]]+(25[6-9]|2[6-9][0-9]|[3-9][0-9]{2,})' "${script}" >/dev/null 2>&1
                then
                        warn_msg "Uses exit code > 255 (wraps modulo 256 in POSIX shells)"
                fi

                # -----------------------------------------------------------------
                # 10. Dangerous Unquoted Variable Removal
                # -----------------------------------------------------------------
                if grep -E 'rm[[:space:]]+-rf[[:space:]]+["'\'']?\$\{?[A-Za-z_][A-Za-z0-9_]*\}?/?["'\'']?[[:space:]]*$' "${script}" >/dev/null 2>&1
                then
                        warn_msg "Potentially dangerous bare 'rm -rf \$VAR' without subpath guard"
                fi

                # -----------------------------------------------------------------
                # 11. Toolkit Documentation & Permissions
                # -----------------------------------------------------------------
                if [ ! -x "${script}" ]
                then
                        warn_msg "File is not marked executable (missing chmod +x)"
                fi

                for header in '#: Name:' '#: Purpose:' '#: Usage:'
                do
                        if ! grep -q "^${header}" "${script}"
                        then
                                warn_msg "Missing self-extracting help header: '${header}'"
                        fi
                done

        } 2>"${tmp_err}"

        if [ "${file_failed}" -ne 0 ] || [ "${file_warned}" -ne 0 ]
        then
                printf '\n%s\n' "${script}"
                cat "${tmp_err}"
        fi

        if [ "${file_failed}" -ne 0 ]
        then
                total_failed=$((total_failed + 1))
                printf '%s FAIL\n' "${repo_name}" >> "${tmp_repo_stats}"
        else
                printf '%s PASS\n' "${repo_name}" >> "${tmp_repo_stats}"
        fi

        total_warnings=$((total_warnings + file_warned))

done < "${tmp_list}"

# -----------------------------------------------------------------
# Per-Repository Summary Breakdown
# -----------------------------------------------------------------
printf '\n====================================================================\n'
printf 'Wintersys Toolkit Lint Summary (Target: %s)\n' "${target_dir}"
printf '====================================================================\n'

if [ -s "${tmp_repo_stats}" ]
then
        awk '
        {
                repo = $1
                status = $2
                total[repo]++
                if (status == "FAIL") failed[repo]++
        }
        END {
                for (r in total) {
                        f = (r in failed) ? failed[r] : 0
                        p = total[r] - f
                        printf "  %-38s Total: %3d | Passed: %3d | Failed: %3d\n", r, total[r], p, f
                }
        }' "${tmp_repo_stats}" | sort
fi

printf '--------------------------------------------------------------------\n'
printf 'Total Scripts Checked: %d | Failed: %d | Warnings: %d\n' "${total_checked}" "${total_failed}" "${total_warnings}"
printf '====================================================================\n'

if [ "${total_failed}" -ne 0 ]
then
        exit 1
fi
exit 0


