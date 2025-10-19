#!/bin/bash
#
# Quick Start - System Analysis
# Run this to get started with system documentation
#

# Get the directory where this script lives
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BOLD}${CYAN}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║          SYSTEM ANALYSIS - QUICK START                       ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo -e "${BOLD}What would you like to do?${NC}\n"

echo -e "${CYAN}1.${NC} ${BOLD}Full System Information${NC}"
echo -e "   Gather comprehensive details about this Pi"
echo -e "   ${YELLOW}→ ./system-info-gatherer.sh${NC}\n"

echo -e "${CYAN}2.${NC} ${BOLD}Find Modified System Files${NC}"
echo -e "   Compare installed files to package defaults"
echo -e "   ${YELLOW}→ ./detect-modified-system-files.sh --config-only${NC}\n"

echo -e "${CYAN}3.${NC} ${BOLD}Quick Config File Check${NC}"
echo -e "   Fast scan of just /etc and /boot"
echo -e "   ${YELLOW}→ ./detect-modified-system-files.sh -c${NC}\n"

echo -e "${CYAN}4.${NC} ${BOLD}Read Documentation${NC}"
echo -e "   Learn how to use these tools"
echo -e "   ${YELLOW}→ cat README-system-analysis.md | less${NC}\n"

echo -e "${BOLD}${GREEN}Recommended workflow:${NC}"
echo -e "${GREEN}1.${NC} Run full system info: ${YELLOW}./system-info-gatherer.sh${NC}"
echo -e "${GREEN}2.${NC} Find modifications: ${YELLOW}./detect-modified-system-files.sh -c${NC}"
echo -e "${GREEN}3.${NC} Review and track important files"
echo -e "${GREEN}4.${NC} Use output to create system.mdc documentation\n"

echo -e "${CYAN}Press 1, 2, 3, or 4 to run (or Ctrl+C to exit):${NC} "
read -n 1 choice
echo ""

case $choice in
    1)
        echo -e "\n${GREEN}Running full system information...${NC}\n"
        ./system-info-gatherer.sh
        ;;
    2)
        echo -e "\n${GREEN}Scanning for modified files...${NC}\n"
        ./detect-modified-system-files.sh --config-only
        ;;
    3)
        echo -e "\n${GREEN}Quick config check...${NC}\n"
        ./detect-modified-system-files.sh -c
        ;;
    4)
        echo -e "\n${GREEN}Opening documentation...${NC}\n"
        less README-system-analysis.md
        ;;
    *)
        echo -e "\n${YELLOW}Invalid choice. Run this script again to try.${NC}"
        ;;
esac

