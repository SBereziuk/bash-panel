#!/bin/bash

# --- Include global settings ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/functions.sh"

PANEL_DATA_DIR="/var/bash_panel/userdata"
MAIL_USERS_FILE="/var/bash_panel/mail_users"

echo -e "${RED}=== DELETE MAIL ACCOUNT ===${NC}"

# --- Step 1: Select Owner ---
users=($(ls -1 "$PANEL_DATA_DIR" 2>/dev/null))
[[ ${#users[@]} -eq 0 ]] && error_exit "No users found."

echo "Select owner:"
select username in "${users[@]}"; do
    [[ -n "$username" ]] && break || echo "Invalid selection."
done

# --- Step 2: Select Account (Compatible loop) ---
accounts=()
# We read the auth file and look for accounts belonging to the user's home
while IFS=: read -r email _ _ _ _ acc_home _; do
    if [[ "$acc_home" == /home/"$username"/mail/* ]]; then
        accounts+=("$email")
    fi
done < "$MAIL_USERS_FILE"

if [ ${#accounts[@]} -eq 0 ]; then
    error_exit "No mail accounts found for user $username."
fi

echo -e "\nSelect account to DELETE:"
select target_email in "${accounts[@]}"; do
    [[ -n "$target_email" ]] && break || echo "Invalid selection."
done

# --- Step 3: Confirmation ---
read -p "Are you sure you want to delete $target_email? (y/N): " confirm
[[ ! $confirm =~ ^[Yy]$ ]] && exit 0

# --- Step 4: Removal ---
# Get path again before deleting from the file
acc_path=$(grep "^$target_email:" "$MAIL_USERS_FILE" | cut -d: -f6)

log "Removing $target_email from auth file..."
# Escape dots for sed
escaped_email=$(echo "$target_email" | sed 's/\./\\./g')
sed -i "/^$escaped_email:/d" "$MAIL_USERS_FILE"

if [ -d "$acc_path" ] && [ -n "$acc_path" ]; then
    log "Deleting physical mailbox files in $acc_path..."
    rm -rf "$acc_path"
else
    log "Warning: Mailbox directory not found or path empty."
fi

echo -e "\n${GREEN}SUCCESS: Account $target_email has been removed.${NC}"
