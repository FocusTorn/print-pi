#!/bin/bash
#
# post-image-changes-analyzer - Show ONLY what changed after base image
# Goal: If you remove everything in this report, system = virgin image (excluding ~)
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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_FILE="$SCRIPT_DIR/post-image-changes.txt"

echo -e "${BOLD}${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║          Post-Image Changes - Manual vs Automatic            ║${NC}"
echo -e "${BOLD}${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Get system install date
SYSTEM_INSTALL_DATE=$(stat -c %W / 2>/dev/null || stat -c %Y / 2>/dev/null)
SYSTEM_INSTALL_HUMAN=$(date -d "@$SYSTEM_INSTALL_DATE" "+%Y-%m-%d" 2>/dev/null || echo "Unknown")

echo -e "${CYAN}Base Image Date:${NC} ${YELLOW}$SYSTEM_INSTALL_HUMAN${NC}"
echo -e "${CYAN}Goal:${NC} Show only changes made AFTER this date"
echo ""

# Temp files
MANUAL_PKGS=$(mktemp)
AUTO_PKGS=$(mktemp)
PIP_PKGS=$(mktemp)
MANUAL_FILES=$(mktemp)
AUTO_FILES=$(mktemp)
trap "rm -f $MANUAL_PKGS $AUTO_PKGS $PIP_PKGS $MANUAL_FILES $AUTO_FILES" EXIT

# ============================================================================
# SECTION 1: MANUAL INSTALLATIONS
# ============================================================================

echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${CYAN}ANALYZING MANUAL INSTALLATIONS${NC}"
echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# APT: Manually installed packages
echo -e "${CYAN}[1/5] Checking apt manually-installed packages...${NC}"
apt-mark showmanual | sort > "$MANUAL_PKGS"
manual_count=$(wc -l < "$MANUAL_PKGS")
echo -e "${GREEN}✓${NC} Found ${BLUE}$manual_count${NC} manually-installed apt packages"

# APT: Auto-installed (dependencies)
apt-mark showauto | sort > "$AUTO_PKGS"
auto_count=$(wc -l < "$AUTO_PKGS")
echo -e "${GREEN}✓${NC} Found ${BLUE}$auto_count${NC} auto-installed dependencies"

# PIP: User-installed Python packages
echo -e "${CYAN}[2/5] Checking pip packages...${NC}"
if command -v pip3 &>/dev/null; then
    pip3 list --format=freeze 2>/dev/null | cut -d= -f1 | sort > "$PIP_PKGS"
    pip_count=$(wc -l < "$PIP_PKGS")
    echo -e "${GREEN}✓${NC} Found ${BLUE}$pip_count${NC} pip packages"
else
    echo -e "${YELLOW}⚠${NC} pip3 not available"
    pip_count=0
fi

# Check /usr/local for manual installs
echo -e "${CYAN}[3/5] Checking /usr/local for manual installations...${NC}"
manual_local_count=$(find /usr/local/{bin,lib,share} -type f 2>/dev/null | wc -l)
echo -e "${GREEN}✓${NC} Found ${BLUE}$manual_local_count${NC} files in /usr/local"

# Check for git clones in common locations
echo -e "${CYAN}[4/5] Checking for git repositories...${NC}"
git_repos=$(find /opt /usr/local /usr/src -name ".git" -type d 2>/dev/null | wc -l)
echo -e "${GREEN}✓${NC} Found ${BLUE}$git_repos${NC} git repositories"

# Check install history for post-image installs
echo -e "${CYAN}[5/5] Analyzing apt history logs...${NC}"
post_install_sessions=0
if [[ -f /var/log/apt/history.log ]]; then
    post_install_sessions=$(zgrep -c "Start-Date:" /var/log/apt/history.log* 2>/dev/null || echo "0")
    echo -e "${GREEN}✓${NC} Found ${BLUE}$post_install_sessions${NC} apt install sessions"
else
    echo -e "${YELLOW}⚠${NC} No apt history available"
fi

echo ""

# ============================================================================
# BUILD DEPENDENCY TREES
# ============================================================================

echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${CYAN}BUILDING DEPENDENCY TREES${NC}"
echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

declare -A pkg_deps
declare -A pkg_files
declare -A pkg_size

echo -e "${CYAN}Building trees for ${BLUE}$manual_count${CYAN} packages...${NC}"

processed=0
while read -r pkg; do
    [[ -z "$pkg" ]] && continue
    ((processed++))
    
    # Get dependencies
    deps=$(apt-cache depends "$pkg" 2>/dev/null | \
        grep "^\s*Depends:" | \
        sed 's/.*Depends: //' | \
        sed 's/<.*>//' | \
        sed 's/ *$//' | \
        sort -u)
    pkg_deps["$pkg"]="$deps"
    
    # Get file count and size
    file_count=$(dpkg -L "$pkg" 2>/dev/null | grep -v "^/$" | wc -l || echo "0")
    pkg_files["$pkg"]=$file_count
    
    size=$(dpkg-query -W -f='${Installed-Size}' "$pkg" 2>/dev/null || echo "0")
    pkg_size["$pkg"]=$size
    
    if [[ $((processed % 50)) -eq 0 ]]; then
        printf "\r  ${CYAN}⟳${NC} Processed ${BLUE}%d${NC}/${BLUE}%d${NC}..." "$processed" "$manual_count"
    fi
done < "$MANUAL_PKGS"

printf "\r  ${GREEN}✓${NC} Processed ${BLUE}%d${NC} packages          \n" "$manual_count"
echo ""

# ============================================================================
# OUTPUT: MANUAL INSTALLATIONS
# ============================================================================

{
    echo "═══════════════════════════════════════════════════════════════"
    echo "POST-IMAGE CHANGES ANALYSIS"
    echo "Generated: $(date)"
    echo "Base Image Date: $SYSTEM_INSTALL_HUMAN"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "GOAL: Show ONLY what changed after base image was written"
    echo "If you remove everything in this report, system = virgin image"
    echo "(excluding /home directory)"
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "SUMMARY"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "Manual Installations (YOU did this):"
    echo "  • APT packages (manual):      $manual_count"
    echo "  • PIP packages:                $pip_count"
    echo "  • Files in /usr/local:         $manual_local_count"
    echo "  • Git repositories:            $git_repos"
    echo ""
    echo "Automatic Installations (pulled as dependencies):"
    echo "  • APT packages (auto):         $auto_count"
    echo ""
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "MANUAL INSTALLATIONS"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "APT PACKAGES (Manually Installed)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Unique apt installs: $manual_count packages"
    cat "$MANUAL_PKGS"
    echo ""
    echo ""
    
    while read -r pkg; do
        [[ -z "$pkg" ]] && continue
        
        files="${pkg_files[$pkg]}"
        size="${pkg_size[$pkg]}"
        size_mb=$((size / 1024))
        
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Origin: apt install $pkg"
        echo "Files: $files  |  Size: ${size_mb}MB"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        
        deps="${pkg_deps[$pkg]}"
        if [[ -n "$deps" ]]; then
            # Build tree structure
            echo "$deps" | while read -r dep; do
                [[ -z "$dep" ]] && continue
                
                # Check if this dep is auto-installed
                if grep -q "^${dep}$" "$AUTO_PKGS" 2>/dev/null; then
                    # Get sub-dependencies
                    subdeps=$(apt-cache depends "$dep" 2>/dev/null | \
                        grep "^\s*Depends:" | \
                        sed 's/.*Depends: //' | \
                        sed 's/<.*>//' | \
                        sed 's/ *$//' | \
                        sort -u)
                    
                    if [[ -n "$subdeps" ]]; then
                        echo "├─ $dep (auto-installed)"
                        echo "$subdeps" | while read -r subdep; do
                            [[ -z "$subdep" ]] && continue
                            echo "│  └─ $subdep"
                        done
                    else
                        echo "└─ $dep (auto-installed)"
                    fi
                fi
            done
        else
            echo "(no dependencies)"
        fi
        
        echo ""
    done < "$MANUAL_PKGS"
    
    if [[ $pip_count -gt 0 ]]; then
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "PIP PACKAGES"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "Unique pip installs: $pip_count packages"
        cat "$PIP_PKGS"
        echo ""
        
        while read -r pkg; do
            [[ -z "$pkg" ]] && continue
            
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "Origin: pip3 install $pkg"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            
            # Get pip package info
            if pip3 show "$pkg" &>/dev/null; then
                version=$(pip3 show "$pkg" 2>/dev/null | grep "^Version:" | cut -d: -f2 | xargs)
                requires=$(pip3 show "$pkg" 2>/dev/null | grep "^Requires:" | cut -d: -f2 | xargs)
                
                echo "Version: $version"
                
                if [[ -n "$requires" ]] && [[ "$requires" != "None" ]]; then
                    echo "Dependencies:"
                    echo "$requires" | tr ',' '\n' | sed 's/^ *//' | while read -r dep; do
                        [[ -z "$dep" ]] && continue
                        
                        # Check if dep has its own deps
                        subdeps=$(pip3 show "$dep" 2>/dev/null | grep "^Requires:" | cut -d: -f2 | xargs)
                        
                        if [[ -n "$subdeps" ]] && [[ "$subdeps" != "None" ]]; then
                            echo "├─ $dep"
                            echo "$subdeps" | tr ',' '\n' | sed 's/^ *//' | while read -r subdep; do
                                [[ -z "$subdep" ]] && continue
                                echo "│  └─ $subdep"
                            done
                        else
                            echo "└─ $dep"
                        fi
                    done
                else
                    echo "(no dependencies)"
                fi
            fi
            
            echo ""
        done < "$PIP_PKGS"
    fi
    
    if [[ $git_repos -gt 0 ]]; then
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "GIT CLONES"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        
        find /opt /usr/local /usr/src -name ".git" -type d 2>/dev/null | while read -r gitdir; do
            repo_dir=$(dirname "$gitdir")
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "Origin: git clone (manual)"
            echo "Location: $repo_dir"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            
            cd "$repo_dir" 2>/dev/null || continue
            remote=$(git remote get-url origin 2>/dev/null || echo "unknown")
            branch=$(git branch --show-current 2>/dev/null || echo "unknown")
            
            echo "Remote: $remote"
            echo "Branch: $branch"
            echo ""
        done
    fi
    
    if [[ $manual_local_count -gt 0 ]]; then
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "MANUAL INSTALLS IN /usr/local"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "Total files: $manual_local_count"
        echo ""
        
        find /usr/local/{bin,lib,share} -type f 2>/dev/null | head -50
        
        if [[ $manual_local_count -gt 50 ]]; then
            echo "... and $((manual_local_count - 50)) more files"
        fi
        echo ""
    fi
    
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "AUTOMATIC INSTALLATIONS (Dependencies)"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "These were automatically installed as dependencies:"
    echo ""
    cat "$AUTO_PKGS"
    echo ""
    echo "Total: $auto_count packages"
    echo ""
    
} > "$OUTPUT_FILE"

# ============================================================================
# DISPLAY SUMMARY
# ============================================================================

echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${GREEN}SUMMARY${NC}"
echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo -e "${BOLD}${YELLOW}📦 MANUAL (YOU installed these)${NC}"
echo -e "  ${CYAN}APT packages:${NC} ${BLUE}$manual_count${NC}"
echo -e "  ${CYAN}PIP packages:${NC} ${BLUE}$pip_count${NC}"
echo -e "  ${CYAN}/usr/local files:${NC} ${BLUE}$manual_local_count${NC}"
echo -e "  ${CYAN}Git repos:${NC} ${BLUE}$git_repos${NC}"
echo ""

echo -e "${BOLD}${BLUE}⚙️  AUTOMATIC (Dependencies/Updates)${NC}"
echo -e "  ${CYAN}APT packages:${NC} ${BLUE}$auto_count${NC}"
echo ""

total_manual=$((manual_count + pip_count))
echo -e "${BOLD}${GREEN}✅ Total Manual Actions: ${BLUE}$total_manual${NC}"
echo ""

echo -e "${GREEN}✓ Detailed report saved to: ${YELLOW}$OUTPUT_FILE${NC}"
echo ""
echo -e "${BOLD}${CYAN}💡 THIS REPORT SHOWS:${NC}"
echo -e "  • Everything YOU installed after base image"
echo -e "  • Full dependency trees (what pulled in what)"
echo -e "  • Remove these = back to virgin image (outside ~)"
echo ""

echo -e "${BOLD}${GREEN}✅ Analysis Complete!${NC}"

