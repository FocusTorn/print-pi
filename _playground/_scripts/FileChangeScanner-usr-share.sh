#!/bin/bash
#
# FileChangeScanner-usr-share - Check /usr/share for untracked data files
#

set -o pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Parse flags
VERBOSE=false
OUTPUT_FILE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--verbose) VERBOSE=true; shift ;;
        -o|--output) OUTPUT_FILE="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Scans /usr/share for untracked data files"
            echo "Finds files NOT owned by any package (manually installed)"
            echo ""
            echo "Options:"
            echo "  -v, --verbose    Show detailed file info"
            echo "  -o, --output     Save results to file"
            echo "  -h, --help       Show this help"
            exit 0
            ;;
        *) shift ;;
    esac
done

echo -e "${BOLD}${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║      FileChangeScanner - Shared Data (/usr/share)             ║${NC}"
echo -e "${BOLD}${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Temp files
UNTRACKED=$(mktemp)
PACKAGE_FILES=$(mktemp)
trap "rm -f $UNTRACKED $PACKAGE_FILES" EXIT

# Count files
echo -e "${CYAN}Scanning /usr/share...${NC}"
total_files=$(find /usr/share -type f 2>/dev/null | wc -l)
echo -e "${GREEN}✓${NC} Found ${BLUE}$total_files${NC} data files"
echo -e "${YELLOW}⚠${NC} This directory is HUGE - scan may take 5-10 minutes..."
echo ""

# Get package-owned files
echo -e "${CYAN}Building package file list...${NC}"
grep -h "usr/share/" /var/lib/dpkg/info/*.list 2>/dev/null | sed 's|^/*|/|' | sort -u > "$PACKAGE_FILES"
pkg_owned=$(wc -l < "$PACKAGE_FILES")
echo -e "${GREEN}✓${NC} Packages own ${BLUE}$pkg_owned${NC} files"
echo ""

# Find untracked
echo -e "${CYAN}Checking for untracked files...${NC}"
checked=0

while IFS= read -r -d '' file; do
    ((checked++))
    
    if ! grep -Fxq "$file" "$PACKAGE_FILES"; then
        echo "$file" >> "$UNTRACKED"
    fi
    
    if [ $((checked % 5000)) -eq 0 ]; then
        percent=$((checked * 100 / total_files))
        found=$(wc -l < "$UNTRACKED" 2>/dev/null || echo "0")
        printf "\r  ${CYAN}[%3d%%]${NC} ${BLUE}%d${NC}/${BLUE}%d${NC} checked | ${YELLOW}%d${NC} untracked" "$percent" "$checked" "$total_files" "$found"
    fi
done < <(find /usr/share -type f -print0 2>/dev/null)

found=$(wc -l < "$UNTRACKED" 2>/dev/null || echo "0")
printf "\r  ${GREEN}✓${NC} Checked ${BLUE}%d${NC} files | Found ${YELLOW}%d${NC} untracked          \n" "$total_files" "$found"
echo ""

# Results
echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${GREEN}RESULTS${NC}"
echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

untracked_count=$(wc -l < "$UNTRACKED" 2>/dev/null || echo "0")

if [ $untracked_count -gt 0 ]; then
    echo -e "${BOLD}${CYAN}▶ Untracked Data Files (${untracked_count})${NC}"
    
    # Show first 100
    head -100 "$UNTRACKED" | while read -r file; do
        echo -e "  ${YELLOW}+${NC} $file"
    done
    
    if [ $untracked_count -gt 100 ]; then
        echo -e "${YELLOW}  ... and $((untracked_count - 100)) more (use -o to save full list)${NC}"
    fi
    echo ""
else
    echo -e "${GREEN}✓ All data files are tracked by packages!${NC}"
    echo ""
fi

# Summary
echo -e "${BOLD}${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${YELLOW}SUMMARY${NC}"
echo -e "${BOLD}${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo -e "${CYAN}Total Files:${NC} ${BLUE}$total_files${NC}"
echo -e "${CYAN}Package-Owned:${NC} ${BLUE}$pkg_owned${NC}"
echo -e "${CYAN}Untracked:${NC} ${YELLOW}$untracked_count${NC}"
echo -e "${CYAN}Scan Time:${NC} ${BLUE}$(($SECONDS))s${NC}"
echo ""

if [ $untracked_count -gt 0 ]; then
    echo -e "${BOLD}${CYAN}💡 COMMON SOURCES:${NC}"
    echo -e "${CYAN}• Application data from manual installs${NC}"
    echo -e "${CYAN}• Custom icons, themes, or fonts${NC}"
    echo -e "${CYAN}• User-added documentation or configs${NC}"
    echo ""
fi

# Save if requested
if [ -n "$OUTPUT_FILE" ]; then
    cat "$UNTRACKED" > "$OUTPUT_FILE"
    echo -e "${GREEN}✓ Saved to: ${YELLOW}$OUTPUT_FILE${NC}"
    echo ""
fi

echo -e "${BOLD}${GREEN}✅ Scan Complete!${NC}"

