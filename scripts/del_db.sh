#!/bin/bash

# --- Path Configuration ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/functions.sh"

PANEL_DATA_DIR="/var/bash_panel/userdata"

echo -e "${RED}=== DELETE DATABASE ===${NC}"

# --- Step 1: Select Database Owner ---
users=($(ls -1 "$PANEL_DATA_DIR" 2>/dev/null))
[[ ${#users[@]} -eq 0 ]] && error_exit "No users found."

echo "Select database owner:"
select username in "${users[@]}"; do
    [[ -n "$username" ]] && break || echo "Invalid selection."
done

# --- Step 2: Select Database to Delete ---
DB_LIST_FILE="$PANEL_DATA_DIR/$username/databases.list"
[[ ! -f "$DB_LIST_FILE" || ! -s "$DB_LIST_FILE" ]] && error_exit "User '$username' has no databases."

# Read database names into an array
databases=()
while IFS='|' read -r db_info _; do
    # Extract DB name from the string DB:name|USER:user...
    db_name=$(echo "$db_info" | cut -d':' -f2)
    databases+=("$db_name")
done < "$DB_LIST_FILE"

echo -e "\nSelect database to DELETE:"
select db_to_delete in "${databases[@]}"; do
    [[ -n "$db_to_delete" ]] && break || echo "Invalid selection."
done

# --- Step 3: Confirmation ---
read -p "Are you sure you want to PERMANENTLY delete database '$db_to_delete' and user '$db_to_delete'? (y/N): " confirm
[[ ! $confirm =~ ^[Yy]$ ]] && exit 0

# --- Step 4: Delete from MySQL ---
log "Deleting database and user: $db_to_delete..."

# Since the DB user has the same name as the database, we drop both
mysql <<EOF
DROP DATABASE IF EXISTS \`${db_to_delete}\`;
DROP USER IF EXISTS '${db_to_delete}'@'localhost';
FLUSH PRIVILEGES;
EOF

if [ $? -eq 0 ]; then
    # --- Step 5: Clean up Metadata ---
    sed -i "/DB:$db_to_delete|/d" "$DB_LIST_FILE"
    
    log "Database $db_to_delete removed from MySQL and metadata."
    echo -e "\n${GREEN}##############################################################################${NC}"
    echo -e "${GREEN}      DATABASE DELETED SUCCESSFULLY        ${NC}"
    echo -e "Removed Name:  ${YELLOW}$db_to_delete${NC}"
    echo -e "Removed User:  ${YELLOW}$db_to_delete${NC}"
    echo -e "Owner:         ${YELLOW}$username${NC}"
    echo -e "${GREEN}##############################################################################${NC}"
else
    error_exit "Failed to delete database from MySQL."
fi
