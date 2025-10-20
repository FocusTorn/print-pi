#!/bin/bash

# ============================================================================
# FORMATTING LIBRARY EXAMPLE
# ============================================================================
# This example demonstrates how to use the shared formatting library
#
# Usage:
#   bash /home/pi/_playground/_scripts/lib/formatting-example.sh
#
# ============================================================================

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source the formatting library
source "${SCRIPT_DIR}/formatting.sh"

# ============================================================================
# EXAMPLE USAGE
# ============================================================================

# Use the fmt.* functions directly (recommended for new scripts)
fmt.header "FORMATTING LIBRARY DEMO"

fmt.section "1. BASIC USAGE"
fmt.subsection "Subsection Example"
fmt.info "Username" "pi"
fmt.info "Home Directory" "/home/pi"
fmt.info "Shell" "bash"

fmt.section "2. COMMAND CHECKING"
fmt.subsection "Installed Commands"
fmt.check_cmd "bash" "--version"
fmt.check_cmd "python3" "--version"
fmt.check_cmd "git" "--version"

fmt.subsection "Not Installed Commands"
fmt.check_cmd "nodejs" "--version"
fmt.check_cmd "npm" "--version"

fmt.section "3. COLORED SUBSECTIONS"
fmt.subsection.red "Error Messages"
fmt.info "Status" "Critical"

fmt.subsection.green "Success Messages"
fmt.info "Status" "Completed"

fmt.subsection.yellow "Warning Messages"
fmt.info "Status" "Attention Required"

fmt.subsection.blue "Information (Default)"
fmt.info "Status" "Normal"

fmt.subsection.cyan "Informational Notes"
fmt.info "Status" "FYI"

fmt.subsection.magenta "Special Notes"
fmt.info "Status" "Important"

fmt.section "4. CUSTOM BOX WIDTHS"
echo -e "\nThe header uses a 95-character wide box by default."
echo -e "You can modify box_width in the function to change this."

# ============================================================================
# END OF DEMO
# ============================================================================

echo -e "\n${GREEN}Demo complete!${NC}\n"

