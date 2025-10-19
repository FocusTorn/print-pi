#!/bin/bash
#
# FileChangeScanner-usr-include - Check /usr/include for untracked header files
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
            echo "Scans /usr/include for untracked header files"
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
echo -e "${BOLD}${CYAN}║      FileChangeScanner - Header Files (/usr/include)          ║${NC}"
echo -e "${BOLD}${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Temp files
UNTRACKED=$(mktemp)
PACKAGE_FILES=$(mktemp)
trap "rm -f $UNTRACKED $PACKAGE_FILES" EXIT

# Count files
echo -e "${CYAN}Scanning /usr/include...${NC}"
total_files=$(find /usr/include -type f 2>/dev/null | wc -l)
echo -e "${GREEN}✓${NC} Found ${BLUE}$total_files${NC} header files"
echo ""

# Get package-owned files
echo -e "${CYAN}Building package file list...${NC}"
grep -h "usr/include/" /var/lib/dpkg/info/*.list 2>/dev/null | sed 's|^/*|/|' | sort -u > "$PACKAGE_FILES"
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
    
    if [ $((checked % 500)) -eq 0 ]; then
        printf "\r  ${CYAN}⟳${NC} Checked ${BLUE}%d${NC}/${BLUE}%d${NC} files..." "$checked" "$total_files"
    fi
done < <(find /usr/include -type f -print0 2>/dev/null)

printf "\r  ${GREEN}✓${NC} Checked ${BLUE}%d${NC} files          \n" "$total_files"
echo ""

# Results
echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${GREEN}RESULTS${NC}"
echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

untracked_count=$(wc -l < "$UNTRACKED" 2>/dev/null || echo "0")

if [ $untracked_count -gt 0 ]; then
    echo -e "${BOLD}${CYAN}▶ Untracked Header Files (${untracked_count})${NC}"
    
    cat "$UNTRACKED" | while read -r file; do
        echo -e "  ${YELLOW}+${NC} $file"
        
        if [ "$VERBOSE" = true ] && [ -f "$file" ]; then
            size=$(stat -c "%s" "$file" 2>/dev/null)
            mtime=$(stat -c "%y" "$file" 2>/dev/null | cut -d. -f1)
            echo -e "      ${YELLOW}Size:${NC} $size bytes  ${YELLOW}Modified:${NC} $mtime"
        fi
    done
    echo ""
else
    echo -e "${GREEN}✓ All header files are tracked by packages!${NC}"
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
    echo -e "${CYAN}• Manual 'make install' from source${NC}"
    echo -e "${CYAN}• Third-party SDKs or libraries${NC}"
    echo -e "${CYAN}• Development tools installed outside apt${NC}"
    echo ""
fi

# Save if requested
if [ -n "$OUTPUT_FILE" ]; then
    cat "$UNTRACKED" > "$OUTPUT_FILE"
    echo -e "${GREEN}✓ Saved to: ${YELLOW}$OUTPUT_FILE${NC}"
    echo ""
fi

echo -e "${BOLD}${GREEN}✅ Scan Complete!${NC}"

