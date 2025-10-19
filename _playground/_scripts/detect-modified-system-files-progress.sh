#!/bin/bash
#
# Detect Modified System Files (with Progress Bar)
# Shows real-time progress while scanning
#

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Configuration
OUTPUT_FILE=""
VERBOSE=false
CHECK_CONFIG_ONLY=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -o|--output) OUTPUT_FILE="$2"; shift 2 ;;
        -v|--verbose) VERBOSE=true; shift ;;
        -c|--config-only) CHECK_CONFIG_ONLY=true; shift ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -o, --output FILE       Save results to file"
            echo "  -v, --verbose          Show detailed output"
            echo "  -c, --config-only      Only check /etc and /boot files"
            echo "  -h, --help             Show this help"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# Progress bar function
draw_progress_bar() {
    local current=$1
    local total=$2
    local width=50
    local percentage=0
    local filled=0
    
    # Guard against division by zero
    if [ $total -gt 0 ]; then
        percentage=$((current * 100 / total))
        filled=$((width * current / total))
        [ $filled -gt $width ] && filled=$width
    fi
    
    local empty=$((width - filled))
    
    # Build the bar
    local bar=""
    for ((i=0; i<filled; i++)); do bar="${bar}█"; done
    for ((i=0; i<empty; i++)); do bar="${bar}░"; done
    
    # Print with carriage return to update same line
    printf "\r${CYAN}[${bar}]${NC} ${YELLOW}%3d%%${NC} ${BLUE}%5d${NC}/${BLUE}%5d${NC} files" "$percentage" "$current" "$total"
}

# Section progress display
section_header() {
    local section="$1"
    local color="$2"
    echo -e "\n${BOLD}${color}▶ $section${NC}"
}

echo -e "${BOLD}${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║    MODIFIED SYSTEM FILES DETECTOR v2.0 (Progress Edition)    ║${NC}"
echo -e "${BOLD}${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if debsums is installed
if ! command -v debsums &> /dev/null; then
    echo -e "${YELLOW}⚠ debsums not installed. Installing...${NC}"
    sudo apt-get update -qq
    sudo apt-get install -y debsums
    echo -e "${GREEN}✓ debsums installed${NC}"
fi

# Temp files
MODIFIED_FILES=$(mktemp)
ALL_FILES=$(mktemp)
trap "rm -f $MODIFIED_FILES $ALL_FILES" EXIT

echo -e "${CYAN}Preparing file lists...${NC}"

# Verify debsums has package data
if ! debsums -l 2>/dev/null | head -1 >/dev/null; then
    echo -e "${RED}✗ Error: debsums cannot list files. This might mean:${NC}"
    echo -e "${YELLOW}  • No packages have MD5 sums installed${NC}"
    echo -e "${YELLOW}  • Try: sudo apt-get install --reinstall debsums${NC}"
    echo -e "${YELLOW}  • Or: sudo debsums_gen (to generate missing sums)${NC}"
    exit 1
fi

# Get list of all files with checksums
if [ "$CHECK_CONFIG_ONLY" = true ]; then
    # Only get /etc and /boot files
    section_header "Scanning /etc directory" "$CYAN"
    debsums -l 2>/dev/null | grep "^/etc" > "$ALL_FILES.etc" || true
    
    section_header "Scanning /boot directory" "$CYAN"
    debsums -l 2>/dev/null | grep "^/boot" > "$ALL_FILES.boot" || true
    
    # Process each directory separately with progress
    for dir_suffix in etc boot; do
        DIR_FILE="$ALL_FILES.$dir_suffix"
        
        if [ ! -f "$DIR_FILE" ] || [ ! -s "$DIR_FILE" ]; then
            echo -e "${YELLOW}No files found in /$dir_suffix${NC}"
            continue
        fi
        
        total_files=$(wc -l < "$DIR_FILE")
        current=0
        
        echo -e "${BOLD}Checking /$dir_suffix files...${NC}"
        draw_progress_bar 0 $total_files
        
        # Check each file
        while IFS= read -r filepath; do
            ((current++))
            
            # Check this specific file
            if ! debsums -s "$filepath" 2>/dev/null; then
                echo "$filepath" >> "$MODIFIED_FILES"
            fi
            
            # Update progress every file (or every N files for better performance)
            if [ $((current % 5)) -eq 0 ] || [ $current -eq $total_files ]; then
                draw_progress_bar $current $total_files
            fi
        done < "$DIR_FILE"
        
        # Final progress update
        draw_progress_bar $total_files $total_files
        echo ""  # New line after progress bar
        
        modified_count=$(grep -c "^/$dir_suffix" "$MODIFIED_FILES" 2>/dev/null || echo "0")
        echo -e "${GREEN}✓${NC} /$dir_suffix: ${YELLOW}$modified_count${NC} modified / ${BLUE}$total_files${NC} checked"
    done
else
    # Full system scan
    section_header "Full System Scan" "$CYAN"
    echo -e "${YELLOW}Collecting file list (this takes a moment)...${NC}"
    debsums -l 2>/dev/null > "$ALL_FILES" || true
    
    total_files=$(wc -l < "$ALL_FILES")
    
    if [ $total_files -eq 0 ]; then
        echo -e "${RED}✗ Error: No files found to check!${NC}"
        echo -e "${YELLOW}This likely means debsums data is missing or corrupted.${NC}"
        echo -e "${YELLOW}Try running: sudo debsums_gen${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓${NC} Found ${BLUE}$total_files${NC} files to check"
    echo ""
    
    current=0
    echo -e "${BOLD}Checking files...${NC}"
    draw_progress_bar 0 $total_files
    
    # Process in batches for better performance
    batch_size=100
    batch_count=0
    batch_files=""
    
    while IFS= read -r filepath; do
        ((current++))
        batch_files="$batch_files$filepath"$'\n'
        ((batch_count++))
        
        # Process batch when full or at end
        if [ $batch_count -ge $batch_size ] || [ $current -eq $total_files ]; then
            # Check batch
            echo "$batch_files" | while IFS= read -r file; do
                [ -z "$file" ] && continue
                if ! debsums -s "$file" 2>/dev/null; then
                    echo "$file" >> "$MODIFIED_FILES"
                fi
            done
            
            # Reset batch
            batch_files=""
            batch_count=0
        fi
        
        # Update progress
        if [ $((current % 10)) -eq 0 ] || [ $current -eq $total_files ]; then
            draw_progress_bar $current $total_files
        fi
    done < "$ALL_FILES"
    
    # Final progress
    draw_progress_bar $total_files $total_files
    echo ""
fi

# Results
echo ""
echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${GREEN}RESULTS${NC}"
echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if [ -s "$MODIFIED_FILES" ]; then
    # Categorize
    declare -A categories
    categories["/etc"]="Configuration Files"
    categories["/boot"]="Boot Configuration"
    categories["/usr/local"]="Local Installations"
    categories["/lib"]="System Libraries"
    categories["/usr/lib"]="User Libraries"
    categories["/usr/bin"]="User Binaries"
    
    for path in "${!categories[@]}"; do
        matches=$(grep "^$path" "$MODIFIED_FILES" 2>/dev/null | sort || true)
        if [ -n "$matches" ]; then
            count=$(echo "$matches" | wc -l)
            echo -e "${BOLD}${CYAN}▶ ${categories[$path]} ($count files)${NC}"
            echo "$matches" | while read -r file; do
                package=$(dpkg -S "$file" 2>/dev/null | cut -d: -f1 || echo "unknown")
                echo -e "${RED}  ✗${NC} $file ${YELLOW}($package)${NC}"
                
                if [ "$VERBOSE" = true ] && [ -f "$file" ]; then
                    mtime=$(stat -c %y "$file" | cut -d. -f1)
                    size=$(stat -c %s "$file")
                    echo -e "      ${YELLOW}Modified:${NC} $mtime  ${YELLOW}Size:${NC} $size bytes"
                fi
            done
            echo ""
        fi
    done
else
    echo -e "${GREEN}✓ No modified system files detected!${NC}"
    echo ""
fi

# Summary
echo -e "${BOLD}${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${YELLOW}SUMMARY${NC}"
echo -e "${BOLD}${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

total_modified=$(wc -l < "$MODIFIED_FILES" 2>/dev/null || echo "0")
etc_modified=$(grep -c "^/etc" "$MODIFIED_FILES" 2>/dev/null || echo "0")
boot_modified=$(grep -c "^/boot" "$MODIFIED_FILES" 2>/dev/null || echo "0")

echo -e "${CYAN}Total Modified Files:${NC} ${YELLOW}$total_modified${NC}"
echo -e "${CYAN}Configuration Files (/etc):${NC} ${YELLOW}$etc_modified${NC}"
echo -e "${CYAN}Boot Files (/boot):${NC} ${YELLOW}$boot_modified${NC}"
echo ""

# Save to file
if [ -n "$OUTPUT_FILE" ]; then
    {
        echo "Modified System Files Report"
        echo "Generated: $(date)"
        echo "========================================"
        echo ""
        cat "$MODIFIED_FILES"
    } > "$OUTPUT_FILE"
    echo -e "${GREEN}✓ Report saved to: ${YELLOW}$OUTPUT_FILE${NC}"
fi

echo -e "${BOLD}${GREEN}✅ Scan complete!${NC}"

