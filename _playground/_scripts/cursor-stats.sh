#!/bin/bash
# cursor-stats.sh - Show Cursor/VS Code extension memory and CPU usage

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}Cursor Extension Resource Monitor${NC}"
echo ""

# Check if Cursor is running
if ! pgrep -f "cursor-server.*node" > /dev/null; then
    echo -e "${YELLOW}Cursor is not running.${NC}"
    exit 0
fi

# Header
printf "%-6s %-6s %-7s %-9s %s\n" "PID" "CPU%" "MEM%" "MEM(MB)" "EXTENSION/PROCESS"
echo "--------------------------------------------------"

# Process list with color coding
ps aux | grep -E "cursor-server.*node" | grep -v grep | while read user pid cpu mem vsz rss tty stat start time cmd rest; do
    mem_mb=$(echo "scale=0; $rss/1024" | bc)
    full_cmd="$cmd $rest"
    
    # Identify the process
    if echo "$full_cmd" | grep -q "keesschollaart.vscode-home-assistant"; then
        name="Home Assistant"
    elif echo "$full_cmd" | grep -q "markdown-language-features"; then
        name="Markdown Language"
    elif echo "$full_cmd" | grep -q "json-language-features"; then
        name="JSON Language"
    elif echo "$full_cmd" | grep -q "yaml-language"; then
        name="YAML Language"
    elif echo "$full_cmd" | grep -q "extensions/.*language"; then
        ext=$(echo "$full_cmd" | grep -oP 'extensions/\K[^/]+(?=/.*language)')
        name="Extension: $ext"
    elif echo "$full_cmd" | grep -q "multiplex-server"; then
        name="Core: multiplex"
    elif echo "$full_cmd" | grep -q "server-main"; then
        name="Core: server-main"
    elif echo "$full_cmd" | grep -q "type=extensionHost"; then
        name="Core: Extension Host"
    elif echo "$full_cmd" | grep -q "type=fileWatcher"; then
        name="Core: File Watcher"
    elif echo "$full_cmd" | grep -q "type=ptyHost"; then
        name="Core: PTY Host"
    else
        name="Core: other"
    fi
    
    # Color code based on memory usage
    if [ "$mem_mb" -gt 500 ]; then
        color=$RED
    elif [ "$mem_mb" -gt 200 ]; then
        color=$YELLOW
    else
        color=$GREEN
    fi
    
    printf "${color}%-6s %-6s %-7s %-9s %s${NC}\n" "$pid" "$cpu%" "$mem%" "$mem_mb" "$name"
done

# Summary
echo ""
echo -e "${BLUE}Summary:${NC}"
total_mem=$(ps aux | grep -E "cursor-server.*node" | grep -v grep | awk '{sum += $6} END {print int(sum/1024)}')
total_cpu=$(ps aux | grep -E "cursor-server.*node" | grep -v grep | awk '{sum += $3} END {printf "%.1f", sum}')
echo -e "Total Memory: ${GREEN}${total_mem} MB${NC}"
echo -e "Total CPU: ${GREEN}${total_cpu}%${NC}"

# Show system memory
echo ""
free -h | awk '/^Mem:/ {printf "System RAM: %s used / %s total (%.1f%%)\n", $3, $2, ($3/$2)*100}'







