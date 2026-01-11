#!/bin/bash

# --- Include global settings ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/functions.sh"

PANEL_DATA_DIR="/var/bash_panel/userdata"
MAIL_USERS_FILE="/var/bash_panel/mail_users"
EXIM_DOMAINS="/etc/exim/domains"

echo -e "${CYAN}=== DELETE MAIL ACCOUNT ===${NC}"

# --- Step 1: Select Owner ---
users=($(ls -1 "$PANEL_DATA_DIR" 2>/dev/null))
[[ ${#users[@]} -eq 0 ]] && error_exit "No users found."

echo "Select account owner:"
select username in "${users[@]}"; do
    [[ -n "$username" ]] && break || echo "Invalid selection."
done

# --- Step 2: Select Domain ---
mail_domains=()
while IFS=: read -r dname owner; do
    owner_trimmed=$(echo "$owner" | xargs)
    if [[ "$owner_trimmed" == "$username" ]]; then
        mail_domains+=("$dname")
    fi
done < "$EXIM_DOMAINS"

[[ ${#mail_domains[@]} -eq 0 ]] && error_exit "No mail domains found for $username."

echo -e "\nSelect domain:"
select domain in "${mail_domains[@]}"; do
    [[ -n "$domain" ]] && break || echo "Invalid selection."
done

# --- Step 3: Select Mail User ---
# Get list of mail users for this specific domain from the auth file
existing_users=($(grep "@$domain:" "$MAIL_USERS_FILE" | cut -d'@' -f1))

[[ ${#existing_users[@]} -eq 0 ]] && error_exit "No mail accounts found for $domain."

echo -e "\nSelect mail account to delete:"
select mail_user in "${existing_users[@]}"; do
    [[ -n "$mail_user" ]] && break || echo "Invalid selection."
done

full_email="${mail_user}@${domain}"

# --- Step 4: Confirmation ---
read -p "Are you sure you want to delete $full_email and all its emails? (y/n): " confirm
[[ "$confirm" != "y" ]] && echo "Aborted." && exit 0

# --- Step 5: Get Path and Remove Data ---
# Extract path from the 6th field of the passwd-file before deleting the record
ACC_PATH=$(grep "^${full_email}:" "$MAIL_USERS_FILE" | cut -d':' -f6)

log "Removing $full_email from $MAIL_USERS_FILE..."
sed -i "/^${full_email}:/d" "$MAIL_USERS_FILE"

if [[ -d "$ACC_PATH" ]]; then
    log "Deleting physical files in $ACC_PATH..."
    rm -rf "$ACC_PATH"
fi

# --- Step 6: Summary Output ---
echo -e "\n${RED}##############################################################################${NC}"
echo -e "${RED}                MAIL ACCOUNT DELETED SUCCESSFULLY                             ${NC}"
echo -e "Account:        $full_email"
echo -e "Owner:          $username"
echo -e "Status:         All files and records removed"
echo -e "${RED}##############################################################################${NC}\n"
