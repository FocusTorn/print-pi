#!/bin/bash

# ============================================================================
# FORMATTING LIBRARY
# ============================================================================
# Reusable formatting functions for bash scripts
# 
# Usage:
#   source /home/pi/_playground/_scripts/lib/formatting.sh
#   fmt.header "My Title"
#   fmt.section "My Section"
#   fmt.subsection "My Subsection"
#   fmt.info "Label" "Value"
#   fmt.check_cmd "command-name" "--version"
#
# ============================================================================

# Color definitions
BOLD='\033[1m'
NC='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'

# ============================================================================
# FORMATTING FUNCTIONS
# ============================================================================

fmt.header() { #>
    local text="$1"
    local box_width=95  # Total width of the box (including borders)
    local content_width=$((box_width - 4))  # Width minus border characters (┃ and spaces)
    
    # Calculate padding needed to center the text
    local text_length=${#text}
    local total_padding=$((content_width - text_length))
    local left_padding=$((total_padding / 2))
    local right_padding=$((total_padding - left_padding))
    
    # Generate repeated border characters
    local border_repeat=$((box_width - 2))  # Minus the corner characters
    local horizontal_line=$(printf '━%.0s' $(seq 1 $border_repeat))
    local empty_line=$(printf ' %.0s' $(seq 1 $content_width))
    
    echo -e "\n${BOLD}${GREEN}"
    echo "┏${horizontal_line}┓"
    echo "┃ ${empty_line} ┃"
    printf "┃%*s%s%*s┃\n" "$((left_padding + 1))" "" "$text" "$((right_padding + 1))" ""
    echo "┃ ${empty_line} ┃"
    echo -e "┗${horizontal_line}┛${NC}"
} #<

fmt.section() { #>
    local text="$1"
    # Calculate visible length (3 for "│  " + text length + 2 for " │")
    local text_length=${#text}
    local prefix_length=3  # "│  "
    local suffix_length=2  # " │"
    local total_content=$((prefix_length + text_length + suffix_length))
    local padding=$((80 - total_content))
    
    echo -e "\n"
    echo -e "${BOLD}${CYAN}┌─────────────────────────────────────────────────────────────────────────────┐${NC}"
    printf "${BOLD}${CYAN}│  %s%*s│${NC}\n" "$text" "$padding" ""
    echo -e "${BOLD}${CYAN}└─────────────────────────────────────────────────────────────────────────────┘${NC}"
} #<

fmt.subsection() { #>
    local text="$1"
    local color="${2:-$BLUE}"  # Default to BLUE if no color specified
    echo -e "\n${color}${BOLD}┌── ${text}${NC}"
} #<

# Color-specific subsection functions
fmt.subsection.red() { #>
    fmt.subsection "$1" "$RED"
} #<

fmt.subsection.green() { #>
    fmt.subsection "$1" "$GREEN"
} #<

fmt.subsection.yellow() { #>
    fmt.subsection "$1" "$YELLOW"
} #<

fmt.subsection.blue() { #>
    fmt.subsection "$1" "$BLUE"
} #<

fmt.subsection.cyan() { #>
    fmt.subsection "$1" "$CYAN"
} #<

fmt.subsection.magenta() { #>
    fmt.subsection "$1" "$MAGENTA"
} #<

fmt.info() { #>
    echo -e "${BLUE}│${NC}  $1: ${YELLOW}$2${NC}"
} #<

fmt.check_cmd() { #>
    local cmd="$1"
    local flag="${2:---version}"
    if command -v "$cmd" &> /dev/null; then
        local version=$($cmd $flag 2>&1 | head -n1)
        echo -e "${BLUE}│${NC}  ${GREEN}✓${NC} $cmd: ${YELLOW}$version${NC}"
    else
        echo -e "${BLUE}│${NC}  ${RED}✗${NC} $cmd: ${YELLOW}Not installed${NC}"
    fi
} #<

# ============================================================================
# EXPORT FUNCTIONS (for compatibility with different shells)
# ============================================================================

# Export functions so they're available in subshells if needed
export -f fmt.header 2>/dev/null || true
export -f fmt.section 2>/dev/null || true
export -f fmt.subsection 2>/dev/null || true
export -f fmt.subsection.red 2>/dev/null || true
export -f fmt.subsection.green 2>/dev/null || true
export -f fmt.subsection.yellow 2>/dev/null || true
export -f fmt.subsection.blue 2>/dev/null || true
export -f fmt.subsection.cyan 2>/dev/null || true
export -f fmt.subsection.magenta 2>/dev/null || true
export -f fmt.info 2>/dev/null || true
export -f fmt.check_cmd 2>/dev/null || true

