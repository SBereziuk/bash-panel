#!/bin/bash

# --- Налаштування шляхів ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/functions.sh"

PANEL_DATA_DIR="/var/bash_panel/userdata"

echo -e "${RED}=== DELETE DATABASE ===${NC}"

# --- Крок 1: Вибір власника бази ---
users=($(ls -1 "$PANEL_DATA_DIR" 2>/dev/null))
[[ ${#users[@]} -eq 0 ]] && error_exit "No users found."

echo "Select database owner:"
select username in "${users[@]}"; do
    [[ -n "$username" ]] && break || echo "Invalid selection."
done

# --- Крок 2: Вибір бази для видалення ---
DB_LIST_FILE="$PANEL_DATA_DIR/$username/databases.list"
[[ ! -f "$DB_LIST_FILE" || ! -s "$DB_LIST_FILE" ]] && error_exit "User '$username' has no databases."

# Зчитуємо назви баз у масив
databases=()
while IFS='|' read -r db_info _; do
    # Витягуємо назву бази з рядка DB:name|USER:user...
    db_name=$(echo "$db_info" | cut -d':' -f2)
    databases+=("$db_name")
done < "$DB_LIST_FILE"

echo -e "\nSelect database to DELETE:"
select db_to_delete in "${databases[@]}"; do
    [[ -n "$db_to_delete" ]] && break || echo "Invalid selection."
done

# --- Крок 3: Підтвердження ---
read -p "Are you sure you want to PERMANENTLY delete database '$db_to_delete' and user '$db_to_delete'? (y/N): " confirm
[[ ! $confirm =~ ^[Yy]$ ]] && exit 0

# --- Крок 4: Видалення в MySQL ---
log "Deleting database and user: $db_to_delete..."

# Оскільки юзер бази у нас називається так само як база, видаляємо обох
mysql <<EOF
DROP DATABASE IF EXISTS \`${db_to_delete}\`;
DROP USER IF EXISTS '${db_to_delete}'@'localhost';
FLUSH PRIVILEGES;
EOF

if [ $? -eq 0 ]; then
    # --- Крок 5: Очищення метаданих ---
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
