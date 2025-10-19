#!/bin/bash
#
# Detect Modified System Files
# Compares installed package files against their original checksums
# Shows which system files have been modified from their package defaults
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

# Output file
OUTPUT_FILE=""
VERBOSE=false
CHECK_CONFIG_ONLY=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -o|--output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -c|--config-only)
            CHECK_CONFIG_ONLY=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -o, --output FILE       Save results to file"
            echo "  -v, --verbose          Show detailed output"
            echo "  -c, --config-only      Only check /etc and /boot files"
            echo "  -h, --help             Show this help"
            echo ""
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo -e "${BOLD}${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║         MODIFIED SYSTEM FILES DETECTOR v1.0                   ║${NC}"
echo -e "${BOLD}${CYAN}║         Comparing installed files to package manifests        ║${NC}"
echo -e "${BOLD}${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if debsums is installed
if ! command -v debsums &> /dev/null; then
    echo -e "${YELLOW}⚠ debsums not installed. Installing...${NC}"
    sudo apt-get update -qq
    sudo apt-get install -y debsums
    echo -e "${GREEN}✓ debsums installed${NC}"
    echo ""
fi

echo -e "${CYAN}Scanning system files... This may take several minutes.${NC}"
echo ""

# Temporary files
MODIFIED_FILES=$(mktemp)
ALL_CHANGES=$(mktemp)
SUMMARY=$(mktemp)

# Cleanup on exit
trap "rm -f $MODIFIED_FILES $ALL_CHANGES $SUMMARY" EXIT

# Function to scan for modified files
scan_modified_files() {
    local scan_path="$1"
    local description="$2"
    
    echo -e "${BOLD}${BLUE}┌─ $description${NC}"
    
    if [ "$CHECK_CONFIG_ONLY" = true ]; then
        # Only check /etc and /boot
        sudo debsums -c 2>/dev/null | grep -E "^/etc|^/boot" >> "$MODIFIED_FILES" || true
    else
        # Full system scan
        if [ -z "$scan_path" ]; then
            sudo debsums -c 2>/dev/null >> "$MODIFIED_FILES" || true
        else
            sudo debsums -c 2>/dev/null | grep "^$scan_path" >> "$MODIFIED_FILES" || true
        fi
    fi
    
    # Count and display
    if [ -n "$scan_path" ]; then
        count=$(grep -c "^$scan_path" "$MODIFIED_FILES" 2>/dev/null || echo "0")
    else
        count=$(wc -l < "$MODIFIED_FILES" 2>/dev/null || echo "0")
    fi
    
    echo -e "${GREEN}  ✓${NC} Found ${YELLOW}$count${NC} modified files"
}

# Scan different areas
if [ "$CHECK_CONFIG_ONLY" = true ]; then
    scan_modified_files "/etc" "Configuration Files (/etc)"
    scan_modified_files "/boot" "Boot Configuration (/boot)"
else
    echo -e "${YELLOW}Running full system scan...${NC}"
    scan_modified_files "" "All System Files"
fi

echo ""
echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${GREEN}RESULTS${NC}"
echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Categorize files
declare -A categories
categories["/etc"]="Configuration Files"
categories["/boot"]="Boot Configuration"
categories["/usr/local"]="Local Installations"
categories["/lib"]="System Libraries"
categories["/usr/lib"]="User Libraries"
categories["/usr/bin"]="User Binaries"
categories["/bin"]="System Binaries"
categories["/sbin"]="System Administration"
categories["/var"]="Variable Data"

# Sort and categorize modified files
if [ -s "$MODIFIED_FILES" ]; then
    # Group by category
    for path in "${!categories[@]}"; do
        matches=$(grep "^$path" "$MODIFIED_FILES" 2>/dev/null || true)
        if [ -n "$matches" ]; then
            count=$(echo "$matches" | wc -l)
            echo -e "${BOLD}${CYAN}▶ ${categories[$path]} ($count files)${NC}"
            echo "$matches" | while read -r file; do
                # Get package name
                package=$(dpkg -S "$file" 2>/dev/null | cut -d: -f1 || echo "unknown")
                
                # Check if file exists
                if [ -f "$file" ]; then
                    mtime=$(stat -c %y "$file" | cut -d. -f1)
                    size=$(stat -c %s "$file")
                    echo -e "${RED}  ✗${NC} $file"
                    if [ "$VERBOSE" = true ]; then
                        echo -e "      ${YELLOW}Package:${NC} $package"
                        echo -e "      ${YELLOW}Modified:${NC} $mtime"
                        echo -e "      ${YELLOW}Size:${NC} $size bytes"
                    fi
                else
                    echo -e "${RED}  ✗${NC} $file ${YELLOW}(missing)${NC}"
                fi
                
                # Add to detailed log
                echo "$path|$file|$package|$(stat -c %y "$file" 2>/dev/null | cut -d. -f1 || echo 'N/A')" >> "$ALL_CHANGES"
            done
            echo ""
        fi
    done
    
    # Catch any files not in predefined categories
    other_files=$(grep -vE "^/etc|^/boot|^/usr/local|^/lib|^/usr/lib|^/usr/bin|^/bin|^/sbin|^/var" "$MODIFIED_FILES" 2>/dev/null || true)
    if [ -n "$other_files" ]; then
        count=$(echo "$other_files" | wc -l)
        echo -e "${BOLD}${CYAN}▶ Other Modified Files ($count files)${NC}"
        echo "$other_files" | while read -r file; do
            package=$(dpkg -S "$file" 2>/dev/null | cut -d: -f1 || echo "unknown")
            echo -e "${RED}  ✗${NC} $file ${YELLOW}($package)${NC}"
        done
        echo ""
    fi
else
    echo -e "${GREEN}✓ No modified system files detected!${NC}"
    echo -e "${CYAN}All installed package files match their original checksums.${NC}"
    echo ""
fi

# Generate summary
echo -e "${BOLD}${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${YELLOW}SUMMARY${NC}"
echo -e "${BOLD}${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

total_modified=$(wc -l < "$MODIFIED_FILES" 2>/dev/null || echo "0")
etc_modified=$(grep -c "^/etc" "$MODIFIED_FILES" 2>/dev/null || echo "0")
boot_modified=$(grep -c "^/boot" "$MODIFIED_FILES" 2>/dev/null || echo "0")
usr_modified=$(grep -c "^/usr" "$MODIFIED_FILES" 2>/dev/null || echo "0")

echo -e "${CYAN}Total Modified Files:${NC} ${YELLOW}$total_modified${NC}"
echo -e "${CYAN}Configuration Files (/etc):${NC} ${YELLOW}$etc_modified${NC}"
echo -e "${CYAN}Boot Files (/boot):${NC} ${YELLOW}$boot_modified${NC}"
echo -e "${CYAN}User Files (/usr):${NC} ${YELLOW}$usr_modified${NC}"
echo ""

# Important notes
if [ $total_modified -gt 0 ]; then
    echo -e "${BOLD}${YELLOW}📝 NOTES:${NC}"
    echo -e "${YELLOW}• Modified files may be intentional customizations${NC}"
    echo -e "${YELLOW}• Files in /etc are often modified during system configuration${NC}"
    echo -e "${YELLOW}• Check if these modifications should be tracked in your overlay system${NC}"
    echo -e "${YELLOW}• Consider using 'system-track' to version control critical changes${NC}"
    echo ""
fi

# Check for files that should be in overlay system
if [ $etc_modified -gt 0 ] || [ $boot_modified -gt 0 ]; then
    echo -e "${BOLD}${CYAN}💡 RECOMMENDATION:${NC}"
    echo -e "${CYAN}Consider tracking these configuration changes in your overlay system:${NC}"
    
    # Show top modified config files
    if [ $etc_modified -gt 0 ]; then
        echo ""
        echo -e "${CYAN}Top modified /etc files:${NC}"
        grep "^/etc" "$MODIFIED_FILES" 2>/dev/null | head -10 | while read -r file; do
            echo -e "  ${YELLOW}→${NC} $file"
        done
    fi
    
    if [ $boot_modified -gt 0 ]; then
        echo ""
        echo -e "${CYAN}Modified /boot files:${NC}"
        grep "^/boot" "$MODIFIED_FILES" 2>/dev/null | while read -r file; do
            echo -e "  ${YELLOW}→${NC} $file"
        done
    fi
    echo ""
fi

# Save to file if requested
if [ -n "$OUTPUT_FILE" ]; then
    {
        echo "Modified System Files Report"
        echo "Generated: $(date)"
        echo "========================================"
        echo ""
        echo "SUMMARY:"
        echo "  Total Modified: $total_modified"
        echo "  /etc files: $etc_modified"
        echo "  /boot files: $boot_modified"
        echo "  /usr files: $usr_modified"
        echo ""
        echo "MODIFIED FILES:"
        echo "========================================"
        cat "$MODIFIED_FILES"
    } > "$OUTPUT_FILE"
    
    echo -e "${GREEN}✓ Report saved to: ${YELLOW}$OUTPUT_FILE${NC}"
    echo ""
fi

# Check for untracked system file modifications
if [ -f /home/pi/.user-scripts/system-tracker ] && [ $total_modified -gt 0 ]; then
    echo -e "${BOLD}${BLUE}🔍 Checking against system-tracker...${NC}"
    
    if [ -f /home/pi/3dp-mods/.system-track-list ]; then
        tracked_count=0
        untracked_count=0
        
        while read -r modified_file; do
            # Remove leading slash for comparison
            file_path="${modified_file#/}"
            
            # Check if this file is tracked
            if grep -q "$modified_file" /home/pi/3dp-mods/.system-track-list 2>/dev/null; then
                ((tracked_count++))
            else
                ((untracked_count++))
            fi
        done < "$MODIFIED_FILES"
        
        echo -e "${GREEN}  ✓${NC} Tracked in system-tracker: ${YELLOW}$tracked_count${NC}"
        echo -e "${RED}  ✗${NC} Not tracked: ${YELLOW}$untracked_count${NC}"
        
        if [ $untracked_count -gt 0 ]; then
            echo ""
            echo -e "${YELLOW}💡 Consider adding untracked files to system-tracker:${NC}"
            echo -e "${CYAN}   system-track add <file>${NC}"
        fi
    fi
    echo ""
fi

echo -e "${BOLD}${GREEN}✅ Scan complete!${NC}"
echo ""

