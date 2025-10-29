#!/bin/bash
# extension-analyzer.sh - Analyze Cursor extensions and their potential impact

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}Cursor Remote Extension Analysis${NC}"
echo ""

# Get Extension Host memory
ext_host_mem=$(ps aux | grep "type=extensionHost" | grep -v grep | awk '{print int($6/1024)}')
if [ -z "$ext_host_mem" ]; then
    echo -e "${RED}Extension Host not running${NC}"
    exit 1
fi

echo -e "Extension Host Total Memory: ${YELLOW}${ext_host_mem} MB${NC}"
echo ""

# List all installed extensions with size
echo -e "${BLUE}Installed Extensions (by size):${NC}"
echo "------------------------------------------------------------"
printf "%-8s %-50s\n" "SIZE" "EXTENSION"
echo "------------------------------------------------------------"

cd ~/.cursor-server/extensions/ 2>/dev/null || cd ~/.vscode-server/extensions/ 2>/dev/null || {
    echo "Extensions directory not found"
    exit 1
}

du -sh */ 2>/dev/null | sort -hr | head -20 | while read size dir; do
    # Clean up extension name
    ext_name=$(echo "$dir" | sed 's/\/$//' | cut -d'-' -f1-2)
    
    # Color code by size
    size_num=$(echo $size | sed 's/[^0-9.]//g')
    size_unit=$(echo $size | sed 's/[0-9.]//g')
    
    if [[ "$size_unit" == "M" ]] && (( $(echo "$size_num > 50" | bc -l) )); then
        color=$RED
    elif [[ "$size_unit" == "M" ]] && (( $(echo "$size_num > 10" | bc -l) )); then
        color=$YELLOW
    else
        color=$GREEN
    fi
    
    printf "${color}%-8s %-50s${NC}\n" "$size" "$ext_name"
done

echo ""
echo -e "${BLUE}Extensions with Language Servers (typically memory-heavy):${NC}"
ls -1 | grep -E "yaml|json|python|rust|typescript|language" | head -10

echo ""
echo -e "${BLUE}Active Extension Processes:${NC}"
ps aux | grep "cursor-server/extensions" | grep -v grep | while read user pid cpu mem vsz rss tty stat start time cmd rest; do
    mem_mb=$(echo "scale=0; $rss/1024" | bc)
    ext=$(echo "$cmd $rest" | grep -oP 'extensions/\K[^/]+' | head -1)
    printf "%-50s ${GREEN}%s MB${NC}\n" "$ext" "$mem_mb"
done

echo ""
echo -e "${YELLOW}Note: Most extensions run inside Extension Host (${ext_host_mem} MB)${NC}"
echo -e "${YELLOW}Only extensions with separate language servers show individual processes${NC}"







