#!/bin/bash

# --- Include global settings ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/functions.sh"

PANEL_DATA_DIR="/var/bash_panel/userdata"
MAIL_USERS_FILE="/var/bash_panel/mail_users"

echo -e "${CYAN}================================================================${NC}"
echo -e "${CYAN}          SERVER RESOURCE OVERVIEW (All Users)          ${NC}"
echo -e "${CYAN}================================================================${NC}"

# Get list of all panel users
users=($(ls -1 "$PANEL_DATA_DIR" 2>/dev/null))

if [ ${#users[@]} -eq 0 ]; then
    echo "No users found in the panel."
    exit 0
fi

# Table Header
printf "${PURPLE}%-12s %-15s %-10s %-10s %-10s %-8s${NC}\n" "USER" "DOMAINS" "DBs" "FTP" "MAIL" "DISK"
echo -e "${BLUE}----------------------------------------------------------------${NC}"

for username in "${users[@]}"; do
    # 1. Count Domains
    dom_count=$(wc -l < "$PANEL_DATA_DIR/$username/domains.list" 2>/dev/null || echo 0)

    # 2. Count Databases
    db_count=$(wc -l < "$PANEL_DATA_DIR/$username/databases.list" 2>/dev/null || echo 0)

    # 3. Count FTP Users
    ftp_count=$(wc -l < "$PANEL_DATA_DIR/$username/ftp_users.list" 2>/dev/null || echo 0)

    # 4. Count Mail Accounts
    # We filter accounts that have the user's home path in the auth file
    mail_count=$(grep -c "/home/$username/mail/" "$MAIL_USERS_FILE" 2>/dev/null || echo 0)

    # 5. Calculate Disk Usage
    # du -sh returns something like "1.2G /home/user", we take only the first part
    disk_usage=$(du -sh "/home/$username" 2>/dev/null | awk '{print $1}')
    [[ -z "$disk_usage" ]] && disk_usage="0"

    # Print Row
    printf "%-12s %-15s %-10s %-10s %-10s %-8s\n" \
        "$username" "$dom_count" "$db_count" "$ftp_count" "$mail_count" "$disk_usage"
done

echo -e "${BLUE}----------------------------------------------------------------${NC}"

# Detailed View Option
echo -e "\nWould you like to see detailed information for a specific user? (y/N)"
read -t 10 -n 1 -r detail_confirm
echo ""

if [[ $detail_confirm =~ ^[Yy]$ ]]; then
    echo "Select user for details:"
    select detail_user in "${users[@]}"; do
        if [[ -n "$detail_user" ]]; then
            echo -e "\n${CYAN}--- Details for $detail_user ---${NC}"
            
            echo -e "${YELLOW}[DOMAINS]${NC}"
            cut -d'|' -f1 "$PANEL_DATA_DIR/$detail_user/domains.list" 2>/dev/null || echo "None"
            
            echo -e "\n${YELLOW}[DATABASES]${NC}"
            cut -d':' -f2 "$PANEL_DATA_DIR/$detail_user/databases.list" | cut -d'|' -f1 2>/dev/null || echo "None"
            
            echo -e "\n${YELLOW}[FTP USERS]${NC}"
            cut -d':' -f2 "$PANEL_DATA_DIR/$detail_user/ftp_users.list" | cut -d'|' -f1 2>/dev/null || echo "None"
            
            echo -e "\n${YELLOW}[MAIL ACCOUNTS]${NC}"
            grep "/home/$detail_user/mail/" "$MAIL_USERS_FILE" | cut -d':' -f1 2>/dev/null || echo "None"
            
            break
        fi
    done
fi

echo -e "\n${CYAN}================================================================${NC}"
