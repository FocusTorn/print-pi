#!/bin/bash
#
# analyze-lib-share-install-history - Deep dive into HOW each origin was installed
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
ORIGINS_FILE="$SCRIPT_DIR/lib-share-origins.txt"
OUTPUT_FILE="$SCRIPT_DIR/lib-share-install-history.txt"

if [ ! -f "$ORIGINS_FILE" ]; then
    echo "Error: $ORIGINS_FILE not found!"
    echo "Run analyze-lib-share-origins.sh first"
    exit 1
fi

echo -e "${BOLD}${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║     Installation History Analyzer - Deep Dive Origins         ║${NC}"
echo -e "${BOLD}${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Temp files
ORIGINS_LIST=$(mktemp)
HISTORY=$(mktemp)
trap "rm -f $ORIGINS_LIST $HISTORY" EXIT

# Get system install date (root filesystem creation)
SYSTEM_INSTALL_DATE=$(stat -c %W / 2>/dev/null || stat -c %Y / 2>/dev/null)
SYSTEM_INSTALL_HUMAN=$(date -d "@$SYSTEM_INSTALL_DATE" "+%Y-%m-%d" 2>/dev/null || echo "Unknown")

echo -e "${CYAN}System Installation Date:${NC} ${YELLOW}$SYSTEM_INSTALL_HUMAN${NC}"
echo ""

# Extract unique origins from the report
echo -e "${CYAN}Extracting origins...${NC}"
grep "^Origin:" "$ORIGINS_FILE" | \
    cut -d: -f2- | \
    sed 's/^ //' | \
    sort -u > "$ORIGINS_LIST"

total_origins=$(wc -l < "$ORIGINS_LIST")
echo -e "${GREEN}✓${NC} Found ${BLUE}$total_origins${NC} unique origins"
echo ""

# Function to detect installation method
detect_install_method() {
    local origin="$1"
    local type="$2"
    local method=""
    local when=""
    local details=""
    
    case "$type" in
        pip*)
            # Check pip history
            pkg_name=$(echo "$origin" | sed 's/Python[^:]*: //')
            
            # Check if in pip list
            if pip3 list 2>/dev/null | grep -qi "^${pkg_name}\s"; then
                version=$(pip3 show "$pkg_name" 2>/dev/null | grep "^Version:" | cut -d: -f2 | xargs)
                location=$(pip3 show "$pkg_name" 2>/dev/null | grep "^Location:" | cut -d: -f2 | xargs)
                
                if [[ "$location" =~ /usr/local/ ]]; then
                    method="pip3 install (system-wide)"
                else
                    method="pip3 install"
                fi
                
                details="version $version"
                
                # Try to find install date from file timestamps
                pip_dir=$(find /usr/lib/python3*/dist-packages /usr/lib/python3*/site-packages /usr/local/lib/python3* -maxdepth 1 -iname "*${pkg_name}*" -type d 2>/dev/null | head -1)
                if [[ -n "$pip_dir" ]]; then
                    install_time=$(stat -c %Y "$pip_dir" 2>/dev/null || echo "0")
                    if [[ "$install_time" -gt "$SYSTEM_INSTALL_DATE" ]]; then
                        when="POST-INSTALL"
                        details="$details, installed $(date -d "@$install_time" "+%Y-%m-%d")"
                    else
                        when="BASE-IMAGE"
                    fi
                fi
            else
                method="pip (not in pip list - manual?)"
                when="UNKNOWN"
            fi
            ;;
            
        cargo)
            # Check for cargo install history
            if command -v cargo &>/dev/null; then
                cargo_home="${CARGO_HOME:-$HOME/.cargo}"
                if [[ -d "$cargo_home" ]]; then
                    method="cargo install"
                    when="POST-INSTALL"
                    details="user cargo installation"
                else
                    method="apt (rust toolchain)"
                    when="CHECK-APT"
                fi
            else
                method="Unknown"
                when="UNKNOWN"
            fi
            ;;
            
        npm)
            pkg_name=$(echo "$origin" | sed 's/Node.js: //')
            
            if command -v npm &>/dev/null; then
                if npm list -g "$pkg_name" &>/dev/null; then
                    method="npm install -g"
                    version=$(npm list -g "$pkg_name" 2>/dev/null | grep "$pkg_name" | head -1 | grep -oP '@\K[^$]+')
                    details="version $version"
                    when="POST-INSTALL"
                else
                    method="npm (package manager?)"
                    when="CHECK-APT"
                fi
            fi
            ;;
            
        manual)
            # Check if it's from a git clone
            dir_name=$(echo "$origin" | sed 's/Manual Install (local): //')
            check_path="/usr/local/lib/$dir_name"
            
            if [[ -d "$check_path/.git" ]]; then
                method="git clone + make install"
                git_remote=$(cd "$check_path" && git remote get-url origin 2>/dev/null || echo "")
                details="from $git_remote"
                when="POST-INSTALL"
            else
                # Check for common build artifacts
                if [[ -f "$check_path/Makefile" ]] || [[ -f "$check_path/configure" ]]; then
                    method="source build (./configure && make install)"
                    when="POST-INSTALL"
                elif [[ -f "$check_path/setup.py" ]]; then
                    method="python setup.py install"
                    when="POST-INSTALL"
                else
                    method="manual copy or script"
                    when="POST-INSTALL"
                fi
            fi
            ;;
            
        fonts|theme)
            pkg_name=$(echo "$origin" | sed 's/[^:]*: //')
            
            # Check if from apt
            if dpkg -l 2>/dev/null | grep -q "fonts-${pkg_name}\|${pkg_name}-theme\|${pkg_name}-icon"; then
                method="apt install"
                when="CHECK-APT"
            else
                # Likely manual
                method="manual install"
                when="POST-INSTALL"
                details="possibly from website or git"
            fi
            ;;
            
        *)
            method="Unknown"
            when="UNKNOWN"
            ;;
    esac
    
    # For items marked CHECK-APT, verify with apt logs
    if [[ "$when" = "CHECK-APT" ]]; then
        pkg_candidates=$(echo "$origin" | sed 's/[^:]*: //' | tr 'A-Z' 'a-z' | sed 's/[_\.]/-/g')
        
        # Check apt history
        if [[ -f /var/log/apt/history.log ]]; then
            if grep -q "$pkg_candidates" /var/log/apt/history.log* 2>/dev/null; then
                install_date=$(zgrep -h "Install:" /var/log/apt/history.log* 2>/dev/null | \
                    grep "$pkg_candidates" | \
                    grep -oP "Start-Date: \K[^$]+" | \
                    head -1)
                
                if [[ -n "$install_date" ]]; then
                    when="POST-INSTALL"
                    details="$details, apt installed $install_date"
                else
                    when="BASE-IMAGE"
                fi
            else
                when="BASE-IMAGE"
            fi
        else
            when="BASE-IMAGE (assumed)"
        fi
    fi
    
    echo "$when|$method|$details"
}

# Analyze each origin
echo -e "${CYAN}Analyzing installation methods...${NC}"
echo -e "${YELLOW}This may take a few moments...${NC}"
echo ""

processed=0

while read -r origin; do
    ((processed++))
    
    # Get type from origins file
    type=$(grep -A2 "^Origin: $origin$" "$ORIGINS_FILE" | grep "^Type:" | cut -d: -f2 | xargs)
    
    result=$(detect_install_method "$origin" "$type")
    
    echo "$type|$origin|$result" >> "$HISTORY"
    
    if [ $((processed % 10)) -eq 0 ]; then
        printf "\r  ${CYAN}⟳${NC} Analyzed ${BLUE}%d${NC}/${BLUE}%d${NC} origins..." "$processed" "$total_origins"
    fi
done < "$ORIGINS_LIST"

printf "\r  ${GREEN}✓${NC} Analyzed ${BLUE}%d${NC} origins          \n" "$total_origins"
echo ""

# Group and display results
echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${GREEN}INSTALLATION HISTORY ANALYSIS${NC}"
echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Count by when installed
base_image_count=$(grep -c "^[^|]*|[^|]*|BASE-IMAGE" "$HISTORY" 2>/dev/null | tr -d '\n' || echo "0")
post_install_count=$(grep -c "^[^|]*|[^|]*|POST-INSTALL" "$HISTORY" 2>/dev/null | tr -d '\n' || echo "0")
unknown_count=$(grep -c "^[^|]*|[^|]*|UNKNOWN" "$HISTORY" 2>/dev/null | tr -d '\n' || echo "0")

echo -e "${BOLD}${YELLOW}📊 INSTALLATION TIMELINE${NC}"
echo -e "${GREEN}  ✓ Base Image (Day 0):${NC} ${BLUE}$base_image_count${NC} origins"
echo -e "${YELLOW}  + Post-Install (User):${NC} ${BLUE}$post_install_count${NC} origins"
echo -e "${RED}  ? Unknown:${NC} ${BLUE}$unknown_count${NC} origins"
echo ""

# Group by type and installation method
echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${CYAN}BY TYPE & INSTALL METHOD${NC}"
echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Sort by type, then by when
sort -t'|' -k1,1 -k3,3 "$HISTORY" | while IFS='|' read -r type origin when method details; do
    # Color by when
    case "$when" in
        BASE-IMAGE*) when_color="$GREEN"; icon="✓" ;;
        POST-INSTALL*) when_color="$YELLOW"; icon="+" ;;
        *) when_color="$RED"; icon="?" ;;
    esac
    
    # Color by type
    case "$type" in
        pip*) type_color="$YELLOW" ;;
        cargo) type_color="$MAGENTA" ;;
        npm) type_color="$GREEN" ;;
        manual) type_color="$RED" ;;
        *) type_color="$BLUE" ;;
    esac
    
    echo -e "${when_color}${icon}${NC} ${type_color}[${type}]${NC} ${BOLD}$origin${NC}"
    echo -e "   ${CYAN}Method:${NC} $method"
    [[ -n "$details" ]] && echo -e "   ${CYAN}Details:${NC} $details"
    echo ""
done

# Summary by method
echo -e "${BOLD}${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${YELLOW}SUMMARY BY INSTALL METHOD${NC}"
echo -e "${BOLD}${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

declare -A method_counts
while IFS='|' read -r type origin when method details; do
    ((method_counts["$method"]++)) || method_counts["$method"]=1
done < "$HISTORY"

# Sort by count
for method in "${!method_counts[@]}"; do
    echo "${method_counts[$method]}|$method"
done | sort -rn -t'|' -k1 | while IFS='|' read -r count method; do
    echo -e "${CYAN}${count}x${NC} $method"
done

echo ""

# Recommendations
echo -e "${BOLD}${CYAN}💡 RECOMMENDATIONS${NC}"
echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if [[ $post_install_count -gt 0 ]]; then
    echo -e "${YELLOW}Post-Install Items (${post_install_count} origins):${NC}"
    echo ""
    
    # Check for specific install methods
    pip_count=$(grep -c "pip" "$HISTORY" 2>/dev/null | tr -d '\n' || echo "0")
    manual_count=$(grep -c "manual\|make install\|git clone" "$HISTORY" 2>/dev/null | tr -d '\n' || echo "0")
    
    if [[ $pip_count -gt 0 ]]; then
        echo -e "  ${YELLOW}Python Packages:${NC}"
        echo -e "    • Generate requirements file: ${CYAN}pip3 freeze > ~/requirements.txt${NC}"
        echo -e "    • Document in setup script for reproducibility"
        echo ""
    fi
    
    if [[ $manual_count -gt 0 ]]; then
        echo -e "  ${YELLOW}Manual Installations:${NC}"
        echo -e "    • Document source URLs and build steps"
        echo -e "    • Create installation script: ${CYAN}~/setup-manual-packages.sh${NC}"
        echo -e "    • Check if available via apt to simplify management"
        echo ""
    fi
fi

echo -e "${CYAN}System Documentation:${NC}"
echo -e "  • Save this report: ${YELLOW}$OUTPUT_FILE${NC}"
echo -e "  • Use for system rebuild/migration planning"
echo -e "  • Track in version control with your configs"
echo ""

# Save detailed report
{
    echo "═══════════════════════════════════════════════════════════════"
    echo "Installation History Analysis"
    echo "Generated: $(date)"
    echo "System Install Date: $SYSTEM_INSTALL_HUMAN"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "SUMMARY"
    echo "-------"
    echo "Total Origins: $total_origins"
    echo "Base Image (Day 0): $base_image_count"
    echo "Post-Install (User): $post_install_count"
    echo "Unknown: $unknown_count"
    echo ""
    echo "INSTALL METHODS"
    echo "---------------"
    for method in "${!method_counts[@]}"; do
        printf "%-40s %3d origins\n" "$method" "${method_counts[$method]}"
    done
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "DETAILED ANALYSIS (sorted by type, then timeline)"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    
    sort -t'|' -k1,1 -k3,3 "$HISTORY" | while IFS='|' read -r type origin when method details; do
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Origin: $origin"
        echo "Type: $type"
        echo "Timeline: $when"
        echo "Install Method: $method"
        [[ -n "$details" ]] && echo "Details: $details"
        echo ""
    done
    
    echo "═══════════════════════════════════════════════════════════════"
    echo "POST-INSTALL ORIGINS (User Installed)"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    
    grep "POST-INSTALL" "$HISTORY" | while IFS='|' read -r type origin when method details; do
        echo "• $origin"
        echo "  Type: $type"
        echo "  Method: $method"
        [[ -n "$details" ]] && echo "  Details: $details"
        echo ""
    done
    
} > "$OUTPUT_FILE"

echo -e "${GREEN}✓ Detailed report saved to: ${YELLOW}$OUTPUT_FILE${NC}"
echo ""
echo -e "${BOLD}${GREEN}✅ Deep Analysis Complete!${NC}"

