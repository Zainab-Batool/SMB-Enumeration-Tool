#!/bin/bash

# SMB Enumeration Professional Tool v2.0
# Author: Cybersecurity Professional
# Description: Interactive SMB scanner with customizable target IP

# Enhanced Colors
RED='\033[1;91m'
GREEN='\033[1;92m'
YELLOW='\033[1;93m'
BLUE='\033[1;94m'
MAGENTA='\033[1;95m'
CYAN='\033[1;96m'
WHITE='\033[1;97m'
NC='\033[0m' # No Color

# Banner with border
clear
echo -e "${CYAN}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║   _____ __  ______  ____           ______                  ║"
echo "║  / ___//  |/  /   |/_  /___  __   / ____/___  __  ______   ║"
echo "║  \__ \/ /|_/ / /| | / / __ \/ /  / /_  / __ \/ / / / __ \ ║"
echo "║ ___/ / /  / / ___ |/ / /_/ / /  / __/ / /_/ / /_/ / / / / ║"
echo "║/____/_/  /_/_/  |_/_/\____/_/  /_/    \____/\__,_/_/ /_/ ║"
echo "║                                                            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo -e "${WHITE}=== SMB Enumeration Professional Tool v2.0 ===${NC}"

# Get target IP from user
read -p "Enter target IP address (e.g., 150.1.7.102 or 150.1.7.104): " TARGET
echo -e "${WHITE}=== Target: ${YELLOW}$TARGET${WHITE} ===${NC}"
echo ""

# Legal disclaimer
echo -e "${RED}**********************************************************************${NC}"
echo -e "${RED}* IMPORTANT: Only use this tool on systems you have permission to scan *${NC}"
echo -e "${RED}* Unauthorized scanning may violate laws and regulations              *${NC}"
echo -e "${RED}**********************************************************************${NC}"
echo ""
read -p "Do you have proper authorization to scan $TARGET? (y/n): " auth
if [ "$auth" != "y" ]; then
    echo -e "${RED}[!] Scanning without authorization is illegal. Exiting...${NC}"
    exit 1
fi

# Dependency checks
check_dependency() {
    if ! command -v $1 &> /dev/null; then
        echo -e "${RED}[!] $1 is not installed. Please install it first.${NC}"
        return 1
    fi
    return 0
}

# Initialize variables
OUTPUT_DIR="smb_enum_results_${TARGET}_$(date +"%Y%m%d_%H%M%S")"
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
HAS_MSF=false

# Check dependencies
section_header() {
    echo -e "\n${CYAN}╔════════════════════════════════════════════════════════════╗"
    echo "║ $1"
    echo "╚════════════════════════════════════════════════════════════╝${NC}\n"
}

section_header "Dependency Check"
check_dependency "nmap" || exit 1
check_dependency "smbclient" || exit 1

if command -v msfconsole &> /dev/null; then
    HAS_MSF=true
    echo -e "${GREEN}[✓] Metasploit Framework is installed${NC}"
else
    echo -e "${YELLOW}[-] Metasploit Framework is not installed. Some features will be limited.${NC}"
fi

# Create output directory structure
mkdir -p "$OUTPUT_DIR/nmap"
mkdir -p "$OUTPUT_DIR/smbclient"
mkdir -p "$OUTPUT_DIR/vulnerabilities"

echo -e "${GREEN}[*] Starting SMB Enumeration against $TARGET at $(date)${NC}"
echo ""

# 1. Basic SMB port scan
section_header "Basic SMB Port Scan"
echo -e "${BLUE}[*] Running initial SMB port scan...${NC}"
nmap -Pn -p 445 --open -T4 $TARGET -oN "$OUTPUT_DIR/nmap/initial_scan.txt"
echo -e "${GREEN}[+] Results saved to ${WHITE}$OUTPUT_DIR/nmap/initial_scan.txt${NC}"
cat "$OUTPUT_DIR/nmap/initial_scan.txt"

# 2. Comprehensive SMB scan
section_header "Comprehensive SMB Enumeration"
echo -e "${BLUE}[*] Running comprehensive SMB scan with Nmap scripts...${NC}"
nmap -Pn -p 445 --script=smb-protocols,smb-security-mode,smb-os-discovery,smb-enum-shares,smb-enum-users,smb-system-info,smb-vuln-* -T4 $TARGET -oN "$OUTPUT_DIR/nmap/full_enumeration.txt"
echo -e "${GREEN}[+] Results saved to ${WHITE}$OUTPUT_DIR/nmap/full_enumeration.txt${NC}"
grep -A 20 "Host script results" "$OUTPUT_DIR/nmap/full_enumeration.txt"

# 3. SMB version detection
section_header "SMB Version Detection"
echo -e "${BLUE}[*] Detecting SMB version...${NC}"
nmap -Pn -p 445 --script=smb-protocols -T4 $TARGET -oN "$OUTPUT_DIR/nmap/version_info.txt"
echo -e "${GREEN}[+] Results saved to ${WHITE}$OUTPUT_DIR/nmap/version_info.txt${NC}"
grep -E "Server|Version|Dialect" "$OUTPUT_DIR/nmap/version_info.txt"

# 4. Enumerate SMB shares
section_header "SMB Share Enumeration"
echo -e "${BLUE}[*] Enumerating SMB shares...${NC}"
smbclient -L //$TARGET -N -d 1 | tee "$OUTPUT_DIR/smbclient/share_enumeration.txt"
echo -e "${GREEN}[+] Results saved to ${WHITE}$OUTPUT_DIR/smbclient/share_enumeration.txt${NC}"

# 5. Check anonymous access
section_header "Anonymous Access Testing"
SHARES=$(grep "Disk" "$OUTPUT_DIR/smbclient/share_enumeration.txt" | awk '{print $1}')
if [ -z "$SHARES" ]; then
    echo -e "${YELLOW}[-] No shares found or unable to enumerate shares${NC}"
else
    for SHARE in $SHARES; do
        echo -e "\n${MAGENTA}[*] Testing share: ${WHITE}$SHARE${NC}"
        smbclient //$TARGET/$SHARE -N -c "ls" 2>&1 | grep -v "NT_STATUS_" | tee -a "$OUTPUT_DIR/smbclient/anonymous_access.txt"
    done
    echo -e "${GREEN}[+] Results saved to ${WHITE}$OUTPUT_DIR/smbclient/anonymous_access.txt${NC}"
fi

# 6. Vulnerability scanning
section_header "Vulnerability Assessment"
echo -e "${BLUE}[*] Checking for known SMB vulnerabilities...${NC}"
nmap -Pn -p 445 --script=smb-vuln-* --script-args=unsafe=1 -T4 $TARGET -oN "$OUTPUT_DIR/vulnerabilities/vulnerability_scan.txt"
echo -e "${GREEN}[+] Results saved to ${WHITE}$OUTPUT_DIR/vulnerabilities/vulnerability_scan.txt${NC}"

# Analyze vulnerabilities
echo -e "\n${MAGENTA}=== VULNERABILITY ANALYSIS ===${NC}"
if grep -q "VULNERABLE" "$OUTPUT_DIR/vulnerabilities/vulnerability_scan.txt"; then
    echo -e "${RED}[!] Critical vulnerabilities detected:${NC}"
    grep "VULNERABLE" "$OUTPUT_DIR/vulnerabilities/vulnerability_scan.txt" | while read -r vuln; do
        echo -e "${RED}- $vuln${NC}"
    done
else
    echo -e "${GREEN}[✓] No critical vulnerabilities detected${NC}"
fi

# 7. Metasploit exploit check
if [ "$HAS_MSF" = true ]; then
    section_header "Metasploit Exploit Check"
    echo -e "${BLUE}[*] Searching for available exploits in Metasploit...${NC}"
    msfconsole -q -x "search type:exploit name:samba; exit" | tee "$OUTPUT_DIR/vulnerabilities/msf_exploits.txt"
    echo -e "${GREEN}[+] Results saved to ${WHITE}$OUTPUT_DIR/vulnerabilities/msf_exploits.txt${NC}"
    
    if grep -q "exploit/windows/smb/ms17_010_eternalblue" "$OUTPUT_DIR/vulnerabilities/msf_exploits.txt"; then
        echo -e "\n${RED}[!] CRITICAL: EternalBlue (MS17-010) exploit available${NC}"
        echo -e "${YELLOW}Metasploit commands to test this vulnerability:"
        echo -e "  msfconsole"
        echo -e "  use exploit/windows/smb/ms17_010_eternalblue"
        echo -e "  set RHOSTS $TARGET"
        echo -e "  set LHOST <your_ip>"
        echo -e "  exploit${NC}"
    fi
fi

# Final summary
section_header "Scan Summary"
echo -e "${WHITE}Target: ${YELLOW}$TARGET${NC}"
echo -e "${WHITE}Scan completed at: ${YELLOW}$TIMESTAMP${NC}"
echo -e "${WHITE}Output directory: ${YELLOW}$OUTPUT_DIR/${NC}"

echo -e "\n${WHITE}Summary of findings:${NC}"
if [ -f "$OUTPUT_DIR/vulnerabilities/vulnerability_scan.txt" ]; then
    grep -q "VULNERABLE" "$OUTPUT_DIR/vulnerabilities/vulnerability_scan.txt" && \
        echo -e "${RED}[!] Critical vulnerabilities detected!${NC}" || \
        echo -e "${GREEN}[✓] No critical vulnerabilities detected${NC}"
fi

if [ -f "$OUTPUT_DIR/smbclient/anonymous_access.txt" ]; then
    grep -q "blocks of size" "$OUTPUT_DIR/smbclient/anonymous_access.txt" && \
        echo -e "${RED}[!] Anonymous access to shares detected!${NC}" || \
        echo -e "${GREEN}[✓] No anonymous access detected${NC}"
fi

echo -e "\n${YELLOW}Next steps:"
echo "- Review the output files in $OUTPUT_DIR/"
echo "- If vulnerabilities were found, consider patching immediately"
echo "- For critical vulnerabilities, use Metasploit modules with caution"
echo -e "${NC}"

echo -e "\n${GREEN}╔════════════════════════════════════════════════════════════╗"
echo "║                 SCAN COMPLETED SUCCESSFULLY                 ║"
echo "╚════════════════════════════════════════════════════════════╝${NC}"