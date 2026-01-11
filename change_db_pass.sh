#!/bin/bash

# --- Include global settings ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/functions.sh"

PANEL_DATA_DIR="/var/bash_panel/userdata"

echo -e "${CYAN}=== CHANGE DATABASE PASSWORD ===${NC}"

# --- Step 1: Select Owner ---
if [ ! -d "$PANEL_DATA_DIR" ] || [ -z "$(ls -A "$PANEL_DATA_DIR")" ]; then
    error_exit "No users found in the system."
fi

users=($(ls -1 "$PANEL_DATA_DIR"))

echo -e "\nSelect database owner:"
select username in "${users[@]}"; do
    [[ -n "$username" ]] && break || echo "Invalid selection."
done

# --- Step 2: Select Database ---
DB_LIST_FILE="$PANEL_DATA_DIR/$username/databases.list"
[[ ! -s "$DB_LIST_FILE" ]] && error_exit "User '$username' has no databases."

databases=()
while IFS='|' read -r db_info _; do
    # Extract DB name from "DB:name|USER:user..."
    db_name=$(echo "$db_info" | cut -d':' -f2 | cut -d'|' -f1)
    databases+=("$db_name")
done < "$DB_LIST_FILE"

echo -e "\nSelect database to change password:"
select target_db in "${databases[@]}"; do
    [[ -n "$target_db" ]] && break || echo "Invalid selection."
done

# --- Step 3: Generate or Input New Password ---
echo -e "\nEnter new password (leave empty to generate a random one):"
read -s -p "New Password: " new_pass
echo "" # For newline

if [ -z "$new_pass" ]; then
    # Generate 16-char random alphanumeric password
    new_pass=$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9' | head -c 16)
    echo -e "Generated Password: ${YELLOW}$new_pass${NC}"
fi

# --- Step 4: Update MySQL ---
log "Updating MySQL password for user '$target_db'..."

# In our setup, DB_USER is the same as DB_NAME
mysql <<EOF
ALTER USER '${target_db}'@'localhost' IDENTIFIED BY '${new_pass}';
FLUSH PRIVILEGES;
EOF

if [ $? -eq 0 ]; then
    # --- Step 5: Update Metadata ---
    # We need to update the password in the databases.list file
    # Replace the old record with the new one containing the new password
    sed -i "s/DB:$target_db|USER:$target_db|PASS:[^ ]*/DB:$target_db|USER:$target_db|PASS:$new_pass/" "$DB_LIST_FILE"
    
    echo -e "\n${GREEN}##############################################################################${NC}"
    echo -e "${GREEN}      PASSWORD UPDATED SUCCESSFULLY        ${NC}"
    echo -e "Database:       ${YELLOW}$target_db${NC}"
    echo -e "Database User:  ${YELLOW}$target_db${NC}"
    echo -e "New Password:   ${YELLOW}$new_pass${NC}"
    echo -e "${GREEN}##############################################################################${NC}"
    echo -e "${RED}Reminder: Update your website configuration files (wp-config.php, etc.)${NC}"
else
    error_exit "Failed to update password in MySQL."
fi
