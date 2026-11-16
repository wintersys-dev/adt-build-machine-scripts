No—the previous version did not handle if ... fi blocks. If a script sets BUILD_HOME or HOME inside a conditional block (such as if [ "${BUILD_HOME}" = "" ]; then ... fi), the previous awk script stopped at the if line and injected the payload before the block finished.
Here is the updated inject_payload.sh script. It tracks if / fi nesting depth so that if BUILD_HOME or HOME is set inside a conditional check at the top of a script, the payload waits until after the closing fi statement.
bash
#!/bin/sh
################################################################################
# Description: Injects a script payload after the license header, leading
#              shell 'set' directives, and any leading BUILD_HOME / HOME
#              assignments—including if/fi blocks that set them.
# Usage:       ./inject_payload.sh /path/to/adt-repo [--dry-run]
################################################################################

set -e

TARGET_DIR="$1"
DRY_RUN="$2"

if [ -z "${TARGET_DIR}" ] || [ ! -d "${TARGET_DIR}" ]; then
    echo "Usage: $0 /path/to/adt-repository [--dry-run]" >&2
    exit 1
fi

# Define a unique marker so the script is idempotent and never injects twice
MARKER="# --- ADT CUSTOM PAYLOAD ---"

# Define the payload block to insert after BUILD_HOME / HOME (and any closing fi)
PAYLOAD="${MARKER}
# Replace these lines with your actual payload
echo \"Running \$(basename \"\$0\") in \${BUILD_HOME:-\${HOME}}\"
# --- END ADT CUSTOM PAYLOAD ---"

export MARKER PAYLOAD

find "${TARGET_DIR}" -type f -name "*.sh" ! -path '*/.git/*' | while read -r file; do
    # Skip if the payload marker is already present
    if grep -qF "${MARKER}" "${file}"; then
        echo "Skipping (already injected): ${file}"
        continue
    fi

    if [ "${DRY_RUN}" = "--dry-run" ]; then
        echo "[DRY RUN] Would inject payload into: ${file}"
        continue
    fi

    # Use awk to skip comments, blank lines, 'set' directives, BUILD_HOME/HOME
    # assignments, and any top-level if/fi blocks used to set BUILD_HOME/HOME.
    awk '
        BEGIN {
            in_preamble = 1
            injected = 0
            if_depth = 0
            in_home_if = 0
        }
        {
            is_comment_or_blank = ($0 ~ /^#/ || $0 ~ /^[[:space:]]*$/)
            is_set_directive    = ($0 ~ /^[[:space:]]*set[[:space:]]+[-+]/)
            is_home_assignment  = ($0 ~ /^[[:space:]]*(export[[:space:]]+)?(BUILD_HOME|HOME)=/)
            is_if_start         = ($0 ~ /^[[:space:]]*if[[:space:]]+/)
            is_fi_end           = ($0 ~ /^[[:space:]]*fi([[:space:]]*;?[[:space:]]*$|#)/)

            if (in_preamble == 1) {
                # Case 1: Inside an if-block that sets BUILD_HOME or HOME
                if (in_home_if == 1) {
                    print $0
                    if (is_if_start) {
                        if_depth++
                    } else if (is_fi_end) {
                        if_depth--
                        if (if_depth == 0) {
                            in_home_if = 0
                        }
                    }
                    next
                }

                # Case 2: Start of a top-level if-block checking BUILD_HOME or HOME
                if (is_if_start && $0 ~ /(BUILD_HOME|HOME)/) {
                    in_home_if = 1
                    if_depth = 1
                    print $0
                    next
                }

                # Case 3: Standard preamble lines (comments, blanks, set, direct assignment)
                if (is_comment_or_blank || is_set_directive || is_home_assignment) {
                    print $0
                    next
                }
            }

            # First non-preamble line reached: inject payload once
            if (injected == 0) {
                print ENVIRON["PAYLOAD"]
                print ""
                injected = 1
                in_preamble = 0
            }
            print $0
        }
        END {
            # Handle scripts containing only preamble lines
            if (injected == 0) {
                print ""
                print ENVIRON["PAYLOAD"]
            }
        }
    ' "${file}" > "${file}.tmp"

    # Preserve original file permissions and replace atomically
    chmod --reference="${file}" "${file}.tmp" 2>/dev/null || chmod +x "${file}.tmp"
    mv "${file}.tmp" "${file}"
    echo "Injected payload into: ${file}"
done
Use code with caution.

How It Handles if ... fi Blocks

• Tracks BUILD_HOME / HOME Conditionals. When a preamble line starts with if and references BUILD_HOME or HOME (e.g., if [ "${BUILD_HOME}" = "" ]; then), awk enters in_home_if mode and keeps printing every line inside that block—including then, else, elif, and nested if blocks—until the matching fi closes it.
• Ignores Operational if Blocks. If a script does not have a BUILD_HOME or HOME if block and goes straight into operational logic (such as if [ -f /tmp/lock ]; then), awk does not treat it as part of the preamble and injects your payload right above it.
• Handles Multiple Sequential Blocks. If a script checks BUILD_HOME in one if ... fi block and HOME in a second if ... fi block right after it, both blocks complete before your payload is inserted.
If you'd like to test this safely before modifying your repositories, let me know:
• Whether any of your scripts check a different variable (such as USER or EUID) in the if condition that sets HOME or BUILD_HOME
• If you want a one-line git diff check to verify the exact insertion point across all modified files
I can adjust the if condition matcher or share the verification command.
