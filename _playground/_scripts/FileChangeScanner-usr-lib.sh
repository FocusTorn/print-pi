#!/bin/bash
#
# FileChangeScanner-usr-lib - Check /usr/lib for untracked libraries
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
            echo "Scans /usr/lib for untracked library files"
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
echo -e "${BOLD}${CYAN}║        FileChangeScanner - Libraries (/usr/lib)               ║${NC}"
echo -e "${BOLD}${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Temp files
UNTRACKED=$(mktemp)
PACKAGE_FILES=$(mktemp)
trap "rm -f $UNTRACKED $PACKAGE_FILES" EXIT

# Count files (excluding huge directories like python, perl)
echo -e "${CYAN}Scanning /usr/lib...${NC}"
total_files=$(find /usr/lib -type f 2>/dev/null | wc -l)
echo -e "${GREEN}✓${NC} Found ${BLUE}$total_files${NC} library files"
echo -e "${YELLOW}⚠${NC} This may take a few minutes..."
echo ""

# Get package-owned files
echo -e "${CYAN}Building package file list...${NC}"
grep -h "usr/lib/" /var/lib/dpkg/info/*.list 2>/dev/null | sed 's|^/*|/|' | sort -u > "$PACKAGE_FILES"
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
    
    if [ $((checked % 1000)) -eq 0 ]; then
        percent=$((checked * 100 / total_files))
        printf "\r  ${CYAN}[%3d%%]${NC} Checked ${BLUE}%d${NC}/${BLUE}%d${NC} files..." "$percent" "$checked" "$total_files"
    fi
done < <(find /usr/lib -type f -print0 2>/dev/null)

printf "\r  ${GREEN}✓${NC} Checked ${BLUE}%d${NC} files          \n" "$total_files"
echo ""

# Results
echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${GREEN}RESULTS${NC}"
echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

untracked_count=$(wc -l < "$UNTRACKED" 2>/dev/null || echo "0")

if [ $untracked_count -gt 0 ]; then
    echo -e "${BOLD}${CYAN}▶ Untracked Library Files (${untracked_count})${NC}"
    
    # Show first 50
    head -50 "$UNTRACKED" | while read -r file; do
        ftype=$(file -b "$file" 2>/dev/null | cut -d, -f1)
        echo -e "  ${YELLOW}+${NC} $file ${NC}[${YELLOW}$ftype${NC}]"
        
        if [ "$VERBOSE" = true ] && [ -f "$file" ]; then
            size=$(stat -c "%s" "$file" 2>/dev/null)
            mtime=$(stat -c "%y" "$file" 2>/dev/null | cut -d. -f1)
            echo -e "      ${YELLOW}Size:${NC} $size bytes  ${YELLOW}Modified:${NC} $mtime"
        fi
    done
    
    if [ $untracked_count -gt 50 ]; then
        echo -e "${YELLOW}  ... and $((untracked_count - 50)) more (use -o to save full list)${NC}"
    fi
    echo ""
else
    echo -e "${GREEN}✓ All library files are tracked by packages!${NC}"
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
    echo -e "${CYAN}• pip install with --user or sudo${NC}"
    echo -e "${CYAN}• Manual 'make install' from source${NC}"
    echo -e "${CYAN}• Third-party installers${NC}"
    echo ""
fi

# Save if requested
if [ -n "$OUTPUT_FILE" ]; then
    cat "$UNTRACKED" > "$OUTPUT_FILE"
    echo -e "${GREEN}✓ Saved to: ${YELLOW}$OUTPUT_FILE${NC}"
    echo ""
fi

echo -e "${BOLD}${GREEN}✅ Scan Complete!${NC}"

