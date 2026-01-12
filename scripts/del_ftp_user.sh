#!/bin/bash

# --- Include global settings ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/functions.sh"

PANEL_DATA_DIR="/var/bash_panel/userdata"

echo -e "${RED}=== DELETE VIRTUAL FTP USER ===${NC}"

# --- Step 1: Select Owner ---
users=($(ls -1 "$PANEL_DATA_DIR" 2>/dev/null))
[[ ${#users[@]} -eq 0 ]] && error_exit "No users found."

echo "Select FTP account owner:"
select username in "${users[@]}"; do
    [[ -n "$username" ]] && break || echo "Invalid selection."
done

# --- Step 2: Select FTP Account ---
FTP_LIST_FILE="$PANEL_DATA_DIR/$username/ftp_users.list"
[[ ! -f "$FTP_LIST_FILE" || ! -s "$FTP_LIST_FILE" ]] && error_exit "User '$username' has no FTP accounts."

# Read FTP accounts into an array
ftp_accounts=()
while IFS='|' read -r ftp_info _; do
    # Extract login from "FTP_USER:login|DOMAIN:domain..."
    ftp_login=$(echo "$ftp_info" | cut -d':' -f2 | cut -d'|' -f1)
    ftp_accounts+=("$ftp_login")
done < "$FTP_LIST_FILE"

echo -e "\nSelect FTP account to DELETE:"
select target_ftp in "${ftp_accounts[@]}"; do
    [[ -n "$target_ftp" ]] && break || echo "Invalid selection."
done

# --- Step 3: Confirmation ---
read -p "Are you sure you want to delete FTP account '$target_ftp'? (y/N): " confirm
[[ ! $confirm =~ ^[Yy]$ ]] && exit 0

# --- Step 4: Remove from Pure-FTPd ---
log "Removing FTP user '$target_ftp' from Pure-FTPd..."

# Remove from virtual users database
pure-pw userdel "$target_ftp"

# Commit changes to binary DB
pure-pw mkdb

if [ $? -eq 0 ]; then
    # --- Step 5: Clean up metadata ---
    sed -i "/FTP_USER:$target_ftp|/d" "$FTP_LIST_FILE"
    
    echo -e "\n${GREEN}##############################################################################${NC}"
    echo -e "${GREEN}      FTP USER DELETED SUCCESSFULLY        ${NC}"
    echo -e "Removed Login:  ${YELLOW}$target_ftp${NC}"
    echo -e "Owner:          ${YELLOW}$username${NC}"
    echo -e "${GREEN}##############################################################################${NC}"
else
    error_exit "Failed to delete FTP user from Pure-FTPd database."
fi
