#!/bin/bash

# --- Include global settings ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/functions.sh"

PANEL_DATA_DIR="/var/bash_panel/userdata"

echo -e "${CYAN}=== CREATE VIRTUAL FTP USER ===${NC}"

# --- Step 1: Select System User (Owner) ---
if [ ! -d "$PANEL_DATA_DIR" ] || [ -z "$(ls -A "$PANEL_DATA_DIR")" ]; then
    error_exit "No users found."
fi

users=($(ls -1 "$PANEL_DATA_DIR"))
echo -e "\nSelect website owner:"
select username in "${users[@]}"; do
    [[ -n "$username" ]] && break || echo "Invalid selection."
done

# --- Step 2: Select Domain ---
USER_DOMAINS_FILE="$PANEL_DATA_DIR/$username/domains.list"
[[ ! -s "$USER_DOMAINS_FILE" ]] && error_exit "User '$username' has no domains."

domains=()
while IFS='|' read -r dname _; do
    [[ -n "$dname" ]] && domains+=("$dname")
done < "$USER_DOMAINS_FILE"

echo -e "\nSelect domain for FTP access:"
select domain in "${domains[@]}"; do
    [[ -n "$domain" ]] && break || echo "Invalid selection."
done

# --- Step 3: Setup FTP Credentials ---
# Correct path to domain root as requested
FTP_PATH="/home/$username/domains/$domain"

echo -e "\nEnter FTP account suffix (prefix '${username}_' will be added automatically):"
read -p "FTP Suffix: " ftp_suffix

# Combine username and suffix
FTP_LOGIN="${username}_${ftp_suffix}"

# Check if the folder exists, just in case
if [ ! -d "$FTP_PATH" ]; then
    error_exit "Domain directory $FTP_PATH does not exist."
fi

# Password generation or input
read -s -p "Enter FTP password (leave empty for random): " ftp_pass
echo ""
if [ -z "$ftp_pass" ]; then
    ftp_pass=$(openssl rand -base64 12 | tr -dc 'a-zA-Z0-9' | head -c 12)
    echo -e "Generated Password: ${YELLOW}$ftp_pass${NC}"
fi

# --- Step 4: Create User in Pure-FTPd ---
log "Adding virtual FTP user '$FTP_LOGIN' mapped to system user '$username'..."

# Create virtual user
# -u : map to system user
# -d : chroot to domain directory
(echo "$ftp_pass"; echo "$ftp_pass") | pure-pw useradd "$FTP_LOGIN" -u "$username" -d "$FTP_PATH"

# Commit changes to database
pure-pw mkdb

if [ $? -eq 0 ]; then
    # Save metadata for later management
    echo "FTP_USER:$FTP_LOGIN|DOMAIN:$domain|PATH:$FTP_PATH" >> "$PANEL_DATA_DIR/$username/ftp_users.list"
    
    echo -e "\n${GREEN}##############################################################################${NC}"
    echo -e "${GREEN}      FTP USER CREATED SUCCESSFULLY        ${NC}"
    echo -e "FTP Login:      ${YELLOW}$FTP_LOGIN${NC}"
    echo -e "Password:       ${YELLOW}$ftp_pass${NC}"
    echo -e "Directory:      ${YELLOW}$FTP_PATH${NC}"
    echo -e "Chroot:         ${CYAN}Locked to Domain Folder${NC}"
    echo -e "${GREEN}##############################################################################${NC}"
else
    error_exit "Failed to create FTP user."
fi
