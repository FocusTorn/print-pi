#!/bin/bash
#
# FileChangeScanner-binaries - Check /usr/bin and /usr/sbin for added/removed files
# Note: /bin -> /usr/bin and /sbin -> /usr/sbin, so we only check the real locations
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
SHOW_ALT=false  # Default: hide alternatives

while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--verbose) VERBOSE=true; shift ;;
        -o|--output) OUTPUT_FILE="$2"; shift 2 ;;
        --show-alt) SHOW_ALT=true; shift ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Scans /usr/bin and /usr/sbin for untracked binaries"
            echo "Finds files NOT owned by any package (manually installed)"
            echo ""
            echo "Options:"
            echo "  -v, --verbose    Show detailed file info"
            echo "  -o, --output     Save results to file"
            echo "  --show-alt       Show alternatives-managed files (default: hidden)"
            echo "  -h, --help       Show this help"
            echo ""
            echo "Note: By default, alternatives-managed files are hidden for cleaner output"
            exit 0
            ;;
        *) shift ;;
    esac
done

echo -e "${BOLD}${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║    FileChangeScanner - Binaries (bin + sbin + libexec)       ║${NC}"
echo -e "${BOLD}${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Temp files
UNTRACKED=$(mktemp)
PACKAGE_FILES=$(mktemp)
trap "rm -f $UNTRACKED $PACKAGE_FILES" EXIT

# Count files
echo -e "${CYAN}Scanning directories...${NC}"
usr_bin_count=$(find /usr/bin -maxdepth 1 -type f -o -type l 2>/dev/null | wc -l)
usr_sbin_count=$(find /usr/sbin -maxdepth 1 -type f -o -type l 2>/dev/null | wc -l)
usr_libexec_count=$(find /usr/libexec -type f -o -type l 2>/dev/null | wc -l)
total_files=$((usr_bin_count + usr_sbin_count + usr_libexec_count))

echo -e "${GREEN}✓${NC} Found ${BLUE}$usr_bin_count${NC} files in /usr/bin"
echo -e "${GREEN}✓${NC} Found ${BLUE}$usr_sbin_count${NC} files in /usr/sbin"
echo -e "${GREEN}✓${NC} Found ${BLUE}$usr_libexec_count${NC} files in /usr/libexec (recursive)"
echo -e "${GREEN}✓${NC} Total: ${BLUE}$total_files${NC} binary files"
echo ""

# Get list of all files that packages own in /usr/bin, /usr/sbin, and /usr/libexec
echo -e "${CYAN}Building package file list...${NC}"
grep -h "usr/bin/" /var/lib/dpkg/info/*.list 2>/dev/null | sed 's|^/*|/|' >> "$PACKAGE_FILES"
grep -h "usr/sbin/" /var/lib/dpkg/info/*.list 2>/dev/null | sed 's|^/*|/|' >> "$PACKAGE_FILES"
grep -h "usr/libexec/" /var/lib/dpkg/info/*.list 2>/dev/null | sed 's|^/*|/|' >> "$PACKAGE_FILES"
sort -u "$PACKAGE_FILES" -o "$PACKAGE_FILES"

pkg_owned=$(wc -l < "$PACKAGE_FILES")
echo -e "${GREEN}✓${NC} Packages own ${BLUE}$pkg_owned${NC} files in these directories"
echo ""

# Find untracked files
echo -e "${CYAN}Checking for untracked files...${NC}"
checked=0

# Check /usr/bin
echo -e "${BOLD}Scanning /usr/bin...${NC}"
for file in /usr/bin/*; do
    [ ! -e "$file" ] && continue  # Skip broken symlinks
    [ -d "$file" ] && continue    # Skip directories
    
    ((checked++))
    
    # Check if this file is NOT in the package list (use -F for fixed string to avoid regex issues)
    if ! grep -Fxq "$file" "$PACKAGE_FILES"; then
        echo "$file|usr/bin" >> "$UNTRACKED"
    fi
    
    # Progress indicator
    if [ $((checked % 100)) -eq 0 ]; then
        printf "\r  ${CYAN}⟳${NC} Checked ${BLUE}%d${NC} files..." "$checked"
    fi
done
printf "\r  ${GREEN}✓${NC} Checked ${BLUE}%d${NC} /usr/bin files          \n" "$usr_bin_count"

# Check /usr/sbin
echo -e "${BOLD}Scanning /usr/sbin...${NC}"
for file in /usr/sbin/*; do
    [ ! -e "$file" ] && continue
    [ -d "$file" ] && continue
    
    ((checked++))
    
    if ! grep -Fxq "$file" "$PACKAGE_FILES"; then
        echo "$file|usr/sbin" >> "$UNTRACKED"
    fi
    
    if [ $((checked % 100)) -eq 0 ]; then
        printf "\r  ${CYAN}⟳${NC} Checked ${BLUE}%d${NC} files..." "$checked"
    fi
done
printf "\r  ${GREEN}✓${NC} Checked ${BLUE}%d${NC} /usr/sbin files          \n" "$usr_sbin_count"

# Check /usr/libexec (recursive)
echo -e "${BOLD}Scanning /usr/libexec...${NC}"
while IFS= read -r -d '' file; do
    [ ! -e "$file" ] && continue
    [ -d "$file" ] && continue
    
    ((checked++))
    
    if ! grep -Fxq "$file" "$PACKAGE_FILES"; then
        echo "$file|usr/libexec" >> "$UNTRACKED"
    fi
    
    if [ $((checked % 100)) -eq 0 ]; then
        printf "\r  ${CYAN}⟳${NC} Checked ${BLUE}%d${NC} files..." "$checked"
    fi
done < <(find /usr/libexec -type f -o -type l 2>/dev/null -print0)
printf "\r  ${GREEN}✓${NC} Checked ${BLUE}%d${NC} /usr/libexec files          \n" "$usr_libexec_count"

echo ""

# Filter alternatives if not showing them
FILTERED_UNTRACKED=$(mktemp)
trap "rm -f $PACKAGE_FILES $UNTRACKED $FILTERED_UNTRACKED" EXIT

if [ "$SHOW_ALT" = false ]; then
    # Filter out alternatives-managed files
    while IFS='|' read -r file dir; do
        basename=$(basename "$file")
        is_alternative=false
        
        if [ -L "$file" ]; then
            target=$(readlink "$file")
            # Check if managed by alternatives OR points to /etc/alternatives
            if update-alternatives --query "$basename" &>/dev/null || [[ "$target" == /etc/alternatives/* ]]; then
                is_alternative=true
            fi
        fi
        
        # Only include if not an alternative
        if [ "$is_alternative" = false ]; then
            echo "$file|$dir" >> "$FILTERED_UNTRACKED"
        fi
    done < "$UNTRACKED"
else
    # Show everything
    cp "$UNTRACKED" "$FILTERED_UNTRACKED"
fi

# Results
echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${GREEN}RESULTS${NC}"
echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

untracked_count=$(wc -l < "$FILTERED_UNTRACKED" 2>/dev/null || echo "0")

if [ $untracked_count -gt 0 ]; then
    # Group by directory
    usr_bin_untracked=$(grep "|usr/bin$" "$FILTERED_UNTRACKED" 2>/dev/null | wc -l || echo "0")
    usr_sbin_untracked=$(grep "|usr/sbin$" "$FILTERED_UNTRACKED" 2>/dev/null | wc -l || echo "0")
    usr_libexec_untracked=$(grep "|usr/libexec$" "$FILTERED_UNTRACKED" 2>/dev/null | wc -l || echo "0")
    
    if [ $usr_bin_untracked -gt 0 ]; then
        echo -e "${BOLD}${CYAN}▶ /usr/bin - Untracked Files (${usr_bin_untracked})${NC}"
        
        shown=0
        grep "|usr/bin$" "$UNTRACKED" | cut -d'|' -f1 | while read -r file; do
            basename=$(basename "$file")
            
            # Check if it's an alternatives symlink and skip if --no-alt
            is_alternative=false
            target=""
            if [ -L "$file" ]; then
                target=$(readlink "$file")
                # Check if managed by alternatives OR points to /etc/alternatives
                if update-alternatives --query "$basename" &>/dev/null || [[ "$target" == /etc/alternatives/* ]]; then
                    is_alternative=true
                    if [ "$NO_ALT" = true ]; then
                        continue  # Skip alternatives if --no-alt flag is set
                    fi
                fi
            fi
            
            ((shown++))
            
            # Determine source
            source_info=""
            if [ -L "$file" ]; then
                # target already set above
                real_target=$(readlink -f "$file" 2>/dev/null || echo "broken")
                
                # Check if it's an alternatives symlink
                if [ "$is_alternative" = true ]; then
                    alt_target=$(update-alternatives --query "$basename" | grep "^Value:" | cut -d' ' -f2)
                    source_info="${GREEN}alternatives${NC} -> $alt_target"
                # Check if target is package-owned
                elif [ "$real_target" != "broken" ] && [ -f "$real_target" ]; then
                    target_pkg=$(dpkg -S "$real_target" 2>/dev/null | cut -d: -f1 || echo "")
                    if [ -n "$target_pkg" ]; then
                        source_info="${BLUE}symlink${NC} -> $target (${YELLOW}$target_pkg${NC})"
                    else
                        source_info="${BLUE}symlink${NC} -> $target"
                    fi
                else
                    source_info="${BLUE}symlink${NC} -> $target"
                fi
            else
                # Not a symlink, check if it's a script
                if [ -f "$file" ]; then
                    ftype=$(file -b "$file" 2>/dev/null | cut -d, -f1)
                    if echo "$ftype" | grep -qi "script"; then
                        source_info="${YELLOW}script${NC} ($ftype)"
                    else
                        source_info="${YELLOW}binary${NC} ($ftype)"
                    fi
                fi
            fi
            
            echo -e "  ${YELLOW}+${NC} $file ${NC}[${source_info}${NC}]"
            
            if [ "$VERBOSE" = true ] && [ -f "$file" ]; then
                size=$(stat -c "%s" "$file" 2>/dev/null)
                mtime=$(stat -c "%y" "$file" 2>/dev/null | cut -d. -f1)
                echo -e "      ${YELLOW}Size:${NC} $size bytes  ${YELLOW}Modified:${NC} $mtime"
            fi
        done
        echo ""
    fi
    
    if [ $usr_sbin_untracked -gt 0 ]; then
        echo -e "${BOLD}${CYAN}▶ /usr/sbin - Untracked Files (${usr_sbin_untracked})${NC}"
        
        grep "|usr/sbin$" "$FILTERED_UNTRACKED" | cut -d'|' -f1 | while read -r file; do
            basename=$(basename "$file")
            
            # Determine source
            source_info=""
            if [ -L "$file" ]; then
                target=$(readlink "$file")
                real_target=$(readlink -f "$file" 2>/dev/null || echo "broken")
                
                # Check if it's an alternatives symlink
                if update-alternatives --query "$basename" &>/dev/null || [[ "$target" == /etc/alternatives/* ]]; then
                    alt_target=$(update-alternatives --query "$basename" | grep "^Value:" | cut -d' ' -f2)
                    source_info="${GREEN}alternatives${NC} -> $alt_target"
                # Check if target is package-owned
                elif [ "$real_target" != "broken" ] && [ -f "$real_target" ]; then
                    target_pkg=$(dpkg -S "$real_target" 2>/dev/null | cut -d: -f1 || echo "")
                    if [ -n "$target_pkg" ]; then
                        source_info="${BLUE}symlink${NC} -> $target (${YELLOW}$target_pkg${NC})"
                    else
                        source_info="${BLUE}symlink${NC} -> $target"
                    fi
                else
                    source_info="${BLUE}symlink${NC} -> $target"
                fi
            else
                # Not a symlink
                if [ -f "$file" ]; then
                    ftype=$(file -b "$file" 2>/dev/null | cut -d, -f1)
                    if echo "$ftype" | grep -qi "script"; then
                        source_info="${YELLOW}script${NC} ($ftype)"
                    else
                        source_info="${YELLOW}binary${NC} ($ftype)"
                    fi
                fi
            fi
            
            echo -e "  ${YELLOW}+${NC} $file ${NC}[${source_info}${NC}]"
            
            if [ "$VERBOSE" = true ] && [ -f "$file" ]; then
                size=$(stat -c "%s" "$file" 2>/dev/null)
                mtime=$(stat -c "%y" "$file" 2>/dev/null | cut -d. -f1)
                echo -e "      ${YELLOW}Size:${NC} $size bytes  ${YELLOW}Modified:${NC} $mtime"
            fi
        done
        echo ""
    fi
    
    if [ $usr_libexec_untracked -gt 0 ]; then
        echo -e "${BOLD}${CYAN}▶ /usr/libexec - Untracked Files (${usr_libexec_untracked})${NC}"
        
        grep "|usr/libexec$" "$FILTERED_UNTRACKED" | cut -d'|' -f1 | while read -r file; do
            basename=$(basename "$file")
            
            # Determine source
            source_info=""
            if [ -L "$file" ]; then
                target=$(readlink "$file")
                real_target=$(readlink -f "$file" 2>/dev/null || echo "broken")
                
                # Check if it's an alternatives symlink
                if update-alternatives --query "$basename" &>/dev/null || [[ "$target" == /etc/alternatives/* ]]; then
                    alt_target=$(update-alternatives --query "$basename" | grep "^Value:" | cut -d' ' -f2)
                    source_info="${GREEN}alternatives${NC} -> $alt_target"
                # Check if target is package-owned
                elif [ "$real_target" != "broken" ] && [ -f "$real_target" ]; then
                    target_pkg=$(dpkg -S "$real_target" 2>/dev/null | cut -d: -f1 || echo "")
                    if [ -n "$target_pkg" ]; then
                        source_info="${BLUE}symlink${NC} -> $target (${YELLOW}$target_pkg${NC})"
                    else
                        source_info="${BLUE}symlink${NC} -> $target"
                    fi
                else
                    source_info="${BLUE}symlink${NC} -> $target"
                fi
            else
                # Not a symlink
                if [ -f "$file" ]; then
                    ftype=$(file -b "$file" 2>/dev/null | cut -d, -f1)
                    if echo "$ftype" | grep -qi "script"; then
                        source_info="${YELLOW}script${NC} ($ftype)"
                    else
                        source_info="${YELLOW}binary${NC} ($ftype)"
                    fi
                fi
            fi
            
            echo -e "  ${YELLOW}+${NC} $file ${NC}[${source_info}${NC}]"
            
            if [ "$VERBOSE" = true ] && [ -f "$file" ]; then
                size=$(stat -c "%s" "$file" 2>/dev/null)
                mtime=$(stat -c "%y" "$file" 2>/dev/null | cut -d. -f1)
                echo -e "      ${YELLOW}Size:${NC} $size bytes  ${YELLOW}Modified:${NC} $mtime"
            fi
        done
        echo ""
    fi
else
    echo -e "${GREEN}✓ All binaries are tracked by packages!${NC}"
    echo -e "${CYAN}No manually installed files found in /usr/bin, /usr/sbin, or /usr/libexec${NC}"
    echo ""
fi

# Summary
echo -e "${BOLD}${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${YELLOW}SUMMARY${NC}"
echo -e "${BOLD}${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo -e "${CYAN}Total Files Scanned:${NC} ${BLUE}$total_files${NC}"
echo -e "${CYAN}Package-Owned Files:${NC} ${BLUE}$pkg_owned${NC}"
echo -e "${CYAN}Untracked Files:${NC} ${YELLOW}$untracked_count${NC}"
echo -e "${CYAN}  • /usr/bin:${NC} ${YELLOW}$usr_bin_untracked${NC}"
echo -e "${CYAN}  • /usr/sbin:${NC} ${YELLOW}$usr_sbin_untracked${NC}"
echo -e "${CYAN}  • /usr/libexec:${NC} ${YELLOW}$usr_libexec_untracked${NC}"
echo -e "${CYAN}Scan Time:${NC} ${BLUE}$(($SECONDS))s${NC}"
echo ""

if [ $untracked_count -gt 0 ]; then
    echo -e "${BOLD}${CYAN}💡 WHAT THIS MEANS:${NC}"
    echo -e "${CYAN}• Untracked files are NOT managed by your package manager${NC}"
    echo -e "${CYAN}• These were likely manually installed or built from source${NC}"
    echo -e "${CYAN}• Common sources: pip, cargo, npm, manual 'make install'${NC}"
    echo -e "${CYAN}• Consider documenting these in your system notes${NC}"
    echo ""
    
    echo -e "${BOLD}${YELLOW}⚠ RECOMMENDATIONS:${NC}"
    echo -e "${YELLOW}1.${NC} Verify each file is intentional and safe"
    echo -e "${YELLOW}2.${NC} Document installation method for future reference"
    echo -e "${YELLOW}3.${NC} Consider if they should be tracked in system-tracker"
    echo -e "${YELLOW}4.${NC} Remove any old/unused manually installed binaries"
    echo ""
fi

# Save if requested
if [ -n "$OUTPUT_FILE" ]; then
    {
        echo "Untracked Binary Files Report"
        echo "Generated: $(date)"
        echo "Total Scanned: $total_files"
        echo "Untracked: $untracked_count"
        echo "========================================"
        echo ""
        cut -d'|' -f1 "$FILTERED_UNTRACKED"
    } > "$OUTPUT_FILE"
    echo -e "${GREEN}✓ Report saved to: ${YELLOW}$OUTPUT_FILE${NC}"
    echo ""
fi

echo -e "${BOLD}${GREEN}✅ Scan Complete!${NC}"

