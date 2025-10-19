#!/bin/bash
#
# analyze-lib-share-origins - Groups untracked files by their installation origin
#

set -o pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INPUT_FILE="$SCRIPT_DIR/lib-share-changes.txt"
OUTPUT_FILE="$SCRIPT_DIR/lib-share-origins.txt"

if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: $INPUT_FILE not found!"
    echo "Run FileChangeScanner-usr-lib-share.sh first"
    exit 1
fi

echo -e "${BOLD}${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║          Origin Analyzer - Grouping by Install Source         ║${NC}"
echo -e "${BOLD}${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Temp files
ORIGINS=$(mktemp)
GROUPED=$(mktemp)
trap "rm -f $ORIGINS $GROUPED" EXIT

echo -e "${CYAN}Analyzing untracked files...${NC}"

# Extract just the file paths from the report
sed -n '/^UNTRACKED/,/^═/p' "$INPUT_FILE" | \
    grep "^/usr" > "$ORIGINS" || true

total_files=$(wc -l < "$ORIGINS")
echo -e "${GREEN}✓${NC} Found ${BLUE}$total_files${NC} untracked files"
echo ""

# Analyze patterns and group by origin
echo -e "${CYAN}Detecting installation sources...${NC}"

declare -A origins
declare -A origin_counts
declare -A origin_types

# Function to detect origin
detect_origin() {
    local file="$1"
    local origin=""
    local type=""
    
    # Python packages (pip)
    if [[ "$file" =~ /usr/lib/python3.*/dist-packages/([^/]+) ]]; then
        pkg="${BASH_REMATCH[1]}"
        origin="Python: $pkg"
        type="pip"
    
    # Python site-packages
    elif [[ "$file" =~ /usr/lib/python3.*/site-packages/([^/]+) ]]; then
        pkg="${BASH_REMATCH[1]}"
        origin="Python (site): $pkg"
        type="pip"
    
    # Python local
    elif [[ "$file" =~ /usr/local/lib/python3.*/([^/]+) ]]; then
        pkg="${BASH_REMATCH[1]}"
        origin="Python (local): $pkg"
        type="pip-local"
    
    # Rust/Cargo
    elif [[ "$file" =~ /usr/lib/rustlib/ ]]; then
        origin="Rust: cargo/rustlib"
        type="cargo"
    
    # Node.js / npm
    elif [[ "$file" =~ /usr/lib/node_modules/([^/]+) ]]; then
        pkg="${BASH_REMATCH[1]}"
        origin="Node.js: $pkg"
        type="npm"
    
    # Perl modules
    elif [[ "$file" =~ /usr/lib/.*/perl5?/([^/]+) ]]; then
        pkg="${BASH_REMATCH[1]}"
        origin="Perl: $pkg"
        type="cpan"
    
    # Ruby gems
    elif [[ "$file" =~ /usr/lib/ruby/gems/.*/gems/([^/]+) ]]; then
        pkg="${BASH_REMATCH[1]}"
        origin="Ruby: $pkg"
        type="gem"
    
    # Go packages
    elif [[ "$file" =~ /usr/lib/go/pkg/ ]]; then
        origin="Go: packages"
        type="go"
    
    # /usr/local (manual installs)
    elif [[ "$file" =~ /usr/local/lib/([^/]+) ]]; then
        pkg="${BASH_REMATCH[1]}"
        origin="Manual Install (local): $pkg"
        type="manual"
    
    elif [[ "$file" =~ /usr/local/share/([^/]+) ]]; then
        pkg="${BASH_REMATCH[1]}"
        origin="Manual Install (local): $pkg"
        type="manual"
    
    # Firmware/drivers
    elif [[ "$file" =~ /usr/lib/firmware/ ]]; then
        origin="Firmware/Drivers"
        type="firmware"
    
    elif [[ "$file" =~ /usr/share/firmware/ ]]; then
        origin="Firmware/Drivers"
        type="firmware"
    
    # Fonts
    elif [[ "$file" =~ /usr/share/fonts/([^/]+) ]]; then
        pkg="${BASH_REMATCH[1]}"
        origin="Fonts: $pkg"
        type="fonts"
    
    # Icons/themes
    elif [[ "$file" =~ /usr/share/icons/([^/]+) ]]; then
        pkg="${BASH_REMATCH[1]}"
        origin="Icons: $pkg"
        type="theme"
    
    elif [[ "$file" =~ /usr/share/themes/([^/]+) ]]; then
        pkg="${BASH_REMATCH[1]}"
        origin="Theme: $pkg"
        type="theme"
    
    # Application data
    elif [[ "$file" =~ /usr/share/([^/]+)/ ]]; then
        pkg="${BASH_REMATCH[1]}"
        origin="Application Data: $pkg"
        type="app-data"
    
    # Generic /usr/lib
    elif [[ "$file" =~ /usr/lib/([^/]+)/ ]]; then
        pkg="${BASH_REMATCH[1]}"
        origin="Library: $pkg"
        type="library"
    
    else
        origin="Unknown: $file"
        type="unknown"
    fi
    
    echo "$type|$origin|$file"
}

# Process all files
processed=0
while read -r file; do
    ((processed++))
    
    result=$(detect_origin "$file")
    echo "$result" >> "$GROUPED"
    
    if [ $((processed % 500)) -eq 0 ]; then
        printf "\r  ${CYAN}⟳${NC} Processed ${BLUE}%d${NC}/${BLUE}%d${NC} files..." "$processed" "$total_files"
    fi
done < "$ORIGINS"

printf "\r  ${GREEN}✓${NC} Processed ${BLUE}%d${NC} files          \n" "$total_files"
echo ""

# Group and count
echo -e "${CYAN}Grouping by origin...${NC}"

while IFS='|' read -r type origin file; do
    if [ -z "${origins[$origin]}" ]; then
        origins[$origin]="$file"
        origin_counts[$origin]=1
        origin_types[$origin]="$type"
    else
        origins[$origin]="${origins[$origin]}"$'\n'"$file"
        ((origin_counts[$origin]++))
    fi
done < "$GROUPED"

echo -e "${GREEN}✓${NC} Found ${BLUE}${#origins[@]}${NC} unique origins"
echo ""

# Display results
echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${GREEN}ORIGINS ANALYSIS${NC}"
echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Sort by count (descending)
for origin in "${!origin_counts[@]}"; do
    echo "${origin_counts[$origin]}|${origin_types[$origin]}|$origin"
done | sort -rn -t'|' -k1 | while IFS='|' read -r count type origin; do
    
    # Color by type
    case "$type" in
        pip*) color="$YELLOW" ;;
        cargo) color="$MAGENTA" ;;
        npm) color="$GREEN" ;;
        manual) color="$RED" ;;
        fonts|theme) color="$CYAN" ;;
        *) color="$BLUE" ;;
    esac
    
    echo -e "${BOLD}${color}▶ $origin${NC} ${BOLD}(${count} files)${NC}"
    
    # Show first few files as examples
    echo "${origins[$origin]}" | head -5 | while read -r file; do
        echo -e "  ${color}•${NC} $file"
    done
    
    if [ $count -gt 5 ]; then
        echo -e "  ${color}...${NC} and $((count - 5)) more"
    fi
    echo ""
done

# Summary by type
echo -e "${BOLD}${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${YELLOW}SUMMARY BY INSTALL METHOD${NC}"
echo -e "${BOLD}${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

declare -A type_counts
declare -A type_groups

for origin in "${!origin_types[@]}"; do
    type="${origin_types[$origin]}"
    count="${origin_counts[$origin]}"
    
    if [ -z "${type_counts[$type]}" ]; then
        type_counts[$type]=$count
        type_groups[$type]=1
    else
        type_counts[$type]=$((${type_counts[$type]} + count))
        type_groups[$type]=$((${type_groups[$type]} + 1))
    fi
done

# Sort and display
for type in pip pip-local cargo npm cpan gem go manual firmware fonts theme app-data library unknown; do
    if [ -n "${type_counts[$type]}" ]; then
        count="${type_counts[$type]}"
        groups="${type_groups[$type]}"
        
        case "$type" in
            pip*) label="Python (pip)" icon="🐍" ;;
            cargo) label="Rust (cargo)" icon="🦀" ;;
            npm) label="Node.js (npm)" icon="📦" ;;
            cpan) label="Perl (cpan)" icon="🐪" ;;
            gem) label="Ruby (gem)" icon="💎" ;;
            go) label="Go packages" icon="🐹" ;;
            manual) label="Manual Install" icon="⚠️ " ;;
            firmware) label="Firmware/Drivers" icon="🔌" ;;
            fonts) label="Fonts" icon="🔤" ;;
            theme) label="Themes/Icons" icon="🎨" ;;
            app-data) label="Application Data" icon="📂" ;;
            library) label="Libraries" icon="📚" ;;
            unknown) label="Unknown" icon="❓" ;;
        esac
        
        echo -e "${icon} ${BOLD}$label${NC}"
        echo -e "   ${CYAN}Groups:${NC} $groups  ${CYAN}Total Files:${NC} $count"
    fi
done

echo ""

# Recommendations
echo -e "${BOLD}${CYAN}💡 RECOMMENDATIONS${NC}"
echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

has_pip=$([ -n "${type_counts[pip]}" ] && echo "yes")
has_manual=$([ -n "${type_counts[manual]}" ] && echo "yes")

if [ -n "$has_pip" ]; then
    echo -e "${YELLOW}Python Packages:${NC}"
    echo -e "  • Document which packages you need: ${CYAN}pip freeze > requirements.txt${NC}"
    echo -e "  • Consider using virtual environments instead of system-wide installs"
    echo ""
fi

if [ -n "$has_manual" ]; then
    echo -e "${YELLOW}Manual Installs:${NC}"
    echo -e "  • Document installation steps for each package"
    echo -e "  • Check if available via apt to avoid manual management"
    echo -e "  • Keep notes on version and source URL"
    echo ""
fi

echo -e "${CYAN}General:${NC}"
echo -e "  • Review if all installations are still needed"
echo -e "  • Consider creating a setup script to reproduce this environment"
echo -e "  • Track important customizations in your system notes"
echo ""

# Save detailed report
{
    echo "═══════════════════════════════════════════════════════════════"
    echo "Origins Analysis - Grouped Untracked Files"
    echo "Generated: $(date)"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "SUMMARY"
    echo "-------"
    echo "Total Untracked Files: $total_files"
    echo "Unique Origins: ${#origins[@]}"
    echo ""
    
    echo "BY INSTALL METHOD"
    echo "-----------------"
    for type in pip pip-local cargo npm cpan gem go manual firmware fonts theme app-data library unknown; do
        if [ -n "${type_counts[$type]}" ]; then
            printf "%-20s Groups: %3d   Files: %5d\n" "$type" "${type_groups[$type]}" "${type_counts[$type]}"
        fi
    done
    
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "DETAILED ORIGINS (sorted by file count)"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    
    for origin in "${!origin_counts[@]}"; do
        echo "${origin_counts[$origin]}|${origin_types[$origin]}|$origin"
    done | sort -rn -t'|' -k1 | while IFS='|' read -r count type origin; do
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Origin: $origin"
        echo "Type: $type"
        echo "Files: $count"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "${origins[$origin]}"
        echo ""
    done
    
} > "$OUTPUT_FILE"

echo -e "${GREEN}✓ Detailed report saved to: ${YELLOW}$OUTPUT_FILE${NC}"
echo ""
echo -e "${BOLD}${GREEN}✅ Analysis Complete!${NC}"

