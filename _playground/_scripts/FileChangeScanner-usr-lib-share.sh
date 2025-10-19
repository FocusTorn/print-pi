#!/bin/bash
#
# FileChangeScanner-usr-lib-share - Combined scan of /usr/lib and /usr/share
# Automatically saves results to lib-share-changes.txt
#

set -o pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Auto-output to file
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_FILE="$SCRIPT_DIR/lib-share-changes.txt"

# Parse flags
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--verbose) VERBOSE=true; shift ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Scans /usr/lib and /usr/share for untracked files"
            echo "Automatically saves results to: lib-share-changes.txt"
            echo ""
            echo "Options:"
            echo "  -v, --verbose    Show detailed file info"
            echo "  -h, --help       Show this help"
            echo ""
            echo "Output file: $OUTPUT_FILE"
            exit 0
            ;;
        *) shift ;;
    esac
done

echo -e "${BOLD}${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║     FileChangeScanner - Libraries & Data (lib + share)        ║${NC}"
echo -e "${BOLD}${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}Output will be saved to:${NC} ${YELLOW}$OUTPUT_FILE${NC}"
echo -e "${YELLOW}⚠  This is a LONG scan - may take 10-15 minutes!${NC}"
echo ""

# Temp files
LIB_UNTRACKED=$(mktemp)
SHARE_UNTRACKED=$(mktemp)
LIB_PACKAGE_FILES=$(mktemp)
SHARE_PACKAGE_FILES=$(mktemp)
trap "rm -f $LIB_UNTRACKED $SHARE_UNTRACKED $LIB_PACKAGE_FILES $SHARE_PACKAGE_FILES" EXIT

START_TIME=$SECONDS

# ============================================================================
# SCAN /usr/lib
# ============================================================================

echo -e "${BOLD}${CYAN}▶ Part 1/2: Scanning /usr/lib${NC}"
echo ""

lib_total=$(find /usr/lib -type f 2>/dev/null | wc -l)
echo -e "${GREEN}✓${NC} Found ${BLUE}$lib_total${NC} library files"

# Get package files
echo -e "${CYAN}Building /usr/lib package list...${NC}"
grep -h "usr/lib/" /var/lib/dpkg/info/*.list 2>/dev/null | sed 's|^/*|/|' | sort -u > "$LIB_PACKAGE_FILES"
lib_pkg_owned=$(wc -l < "$LIB_PACKAGE_FILES")
echo -e "${GREEN}✓${NC} Packages own ${BLUE}$lib_pkg_owned${NC} files"
echo ""

# Scan
echo -e "${CYAN}Checking /usr/lib files...${NC}"
checked=0

while IFS= read -r -d '' file; do
    ((checked++))
    
    if ! grep -Fxq "$file" "$LIB_PACKAGE_FILES"; then
        echo "$file" >> "$LIB_UNTRACKED"
    fi
    
    if [ $((checked % 1000)) -eq 0 ]; then
        percent=$((checked * 100 / lib_total))
        found=$(wc -l < "$LIB_UNTRACKED" 2>/dev/null || echo "0")
        elapsed=$((SECONDS - START_TIME))
        printf "\r  ${CYAN}[%3d%%]${NC} ${BLUE}%d${NC}/${BLUE}%d${NC} | ${YELLOW}%d${NC} untracked | ${CYAN}%ds${NC}" \
            "$percent" "$checked" "$lib_total" "$found" "$elapsed"
    fi
done < <(find /usr/lib -type f -print0 2>/dev/null)

lib_untracked=$(wc -l < "$LIB_UNTRACKED" 2>/dev/null || echo "0")
elapsed=$((SECONDS - START_TIME))
printf "\r  ${GREEN}✓${NC} ${BLUE}%d${NC} files | ${YELLOW}%d${NC} untracked | ${CYAN}%ds${NC}          \n" \
    "$lib_total" "$lib_untracked" "$elapsed"

echo ""

# ============================================================================
# SCAN /usr/share
# ============================================================================

echo -e "${BOLD}${CYAN}▶ Part 2/2: Scanning /usr/share${NC}"
echo ""

share_total=$(find /usr/share -type f 2>/dev/null | wc -l)
echo -e "${GREEN}✓${NC} Found ${BLUE}$share_total${NC} data files"

# Get package files
echo -e "${CYAN}Building /usr/share package list...${NC}"
grep -h "usr/share/" /var/lib/dpkg/info/*.list 2>/dev/null | sed 's|^/*|/|' | sort -u > "$SHARE_PACKAGE_FILES"
share_pkg_owned=$(wc -l < "$SHARE_PACKAGE_FILES")
echo -e "${GREEN}✓${NC} Packages own ${BLUE}$share_pkg_owned${NC} files"
echo ""

# Scan
echo -e "${CYAN}Checking /usr/share files...${NC}"
checked=0

while IFS= read -r -d '' file; do
    ((checked++))
    
    if ! grep -Fxq "$file" "$SHARE_PACKAGE_FILES"; then
        echo "$file" >> "$SHARE_UNTRACKED"
    fi
    
    if [ $((checked % 5000)) -eq 0 ]; then
        percent=$((checked * 100 / share_total))
        found=$(wc -l < "$SHARE_UNTRACKED" 2>/dev/null || echo "0")
        elapsed=$((SECONDS - START_TIME))
        printf "\r  ${CYAN}[%3d%%]${NC} ${BLUE}%d${NC}/${BLUE}%d${NC} | ${YELLOW}%d${NC} untracked | ${CYAN}%ds${NC}" \
            "$percent" "$checked" "$share_total" "$found" "$elapsed"
    fi
done < <(find /usr/share -type f -print0 2>/dev/null)

share_untracked=$(wc -l < "$SHARE_UNTRACKED" 2>/dev/null || echo "0")
elapsed=$((SECONDS - START_TIME))
printf "\r  ${GREEN}✓${NC} ${BLUE}%d${NC} files | ${YELLOW}%d${NC} untracked | ${CYAN}%ds${NC}          \n" \
    "$share_total" "$share_untracked" "$elapsed"

echo ""

# ============================================================================
# RESULTS
# ============================================================================

echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${GREEN}RESULTS${NC}"
echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

total_untracked=$((lib_untracked + share_untracked))

if [ $lib_untracked -gt 0 ]; then
    echo -e "${BOLD}${CYAN}▶ /usr/lib - Untracked Files (${lib_untracked})${NC}"
    
    # Show first 20
    head -20 "$LIB_UNTRACKED" | while read -r file; do
        ftype=$(file -b "$file" 2>/dev/null | cut -d, -f1)
        echo -e "  ${YELLOW}+${NC} $file ${NC}[${YELLOW}$ftype${NC}]"
    done
    
    if [ $lib_untracked -gt 20 ]; then
        echo -e "${YELLOW}  ... and $((lib_untracked - 20)) more${NC}"
    fi
    echo ""
fi

if [ $share_untracked -gt 0 ]; then
    echo -e "${BOLD}${CYAN}▶ /usr/share - Untracked Files (${share_untracked})${NC}"
    
    # Show first 20
    head -20 "$SHARE_UNTRACKED" | while read -r file; do
        echo -e "  ${YELLOW}+${NC} $file"
    done
    
    if [ $share_untracked -gt 20 ]; then
        echo -e "${YELLOW}  ... and $((share_untracked - 20)) more${NC}"
    fi
    echo ""
fi

if [ $total_untracked -eq 0 ]; then
    echo -e "${GREEN}✓ All files in /usr/lib and /usr/share are tracked by packages!${NC}"
    echo ""
fi

# ============================================================================
# SUMMARY
# ============================================================================

echo -e "${BOLD}${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${YELLOW}SUMMARY${NC}"
echo -e "${BOLD}${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

total_files=$((lib_total + share_total))
total_pkg_owned=$((lib_pkg_owned + share_pkg_owned))

echo -e "${CYAN}Total Files Scanned:${NC} ${BLUE}$total_files${NC} (${BLUE}$lib_total${NC} lib + ${BLUE}$share_total${NC} share)"
echo -e "${CYAN}Package-Owned:${NC} ${BLUE}$total_pkg_owned${NC} (${BLUE}$lib_pkg_owned${NC} lib + ${BLUE}$share_pkg_owned${NC} share)"
echo -e "${CYAN}Untracked:${NC} ${YELLOW}$total_untracked${NC} (${YELLOW}$lib_untracked${NC} lib + ${YELLOW}$share_untracked${NC} share)"
echo -e "${CYAN}Scan Time:${NC} ${BLUE}$(($SECONDS))s${NC} ($((SECONDS / 60))m $((SECONDS % 60))s)"
echo ""

if [ $total_untracked -gt 0 ]; then
    echo -e "${BOLD}${CYAN}💡 COMMON SOURCES:${NC}"
    echo -e "${CYAN}• pip/cargo/npm installs${NC}"
    echo -e "${CYAN}• Manual 'make install' from source${NC}"
    echo -e "${CYAN}• Third-party application installers${NC}"
    echo -e "${CYAN}• Custom themes, icons, or fonts${NC}"
    echo ""
fi

# ============================================================================
# SAVE TO FILE
# ============================================================================

echo -e "${CYAN}Saving results to file...${NC}"

{
    echo "═══════════════════════════════════════════════════════════════"
    echo "Untracked Files in /usr/lib and /usr/share"
    echo "Generated: $(date)"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "SUMMARY"
    echo "-------"
    echo "Total Files Scanned: $total_files"
    echo "  /usr/lib:  $lib_total files"
    echo "  /usr/share: $share_total files"
    echo ""
    echo "Package-Owned: $total_pkg_owned"
    echo "  /usr/lib:  $lib_pkg_owned files"
    echo "  /usr/share: $share_pkg_owned files"
    echo ""
    echo "Untracked: $total_untracked"
    echo "  /usr/lib:  $lib_untracked files"
    echo "  /usr/share: $share_untracked files"
    echo ""
    echo "Scan Time: $(($SECONDS))s"
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    
    if [ $lib_untracked -gt 0 ]; then
        echo "UNTRACKED /usr/lib FILES ($lib_untracked)"
        echo "---------------------------------------"
        cat "$LIB_UNTRACKED"
        echo ""
    fi
    
    if [ $share_untracked -gt 0 ]; then
        echo "UNTRACKED /usr/share FILES ($share_untracked)"
        echo "-----------------------------------------"
        cat "$SHARE_UNTRACKED"
        echo ""
    fi
    
    echo "═══════════════════════════════════════════════════════════════"
    echo "End of Report"
    echo "═══════════════════════════════════════════════════════════════"
} > "$OUTPUT_FILE"

echo -e "${GREEN}✓ Report saved to: ${YELLOW}$OUTPUT_FILE${NC}"
echo ""
echo -e "${BOLD}${GREEN}✅ Scan Complete!${NC}"

