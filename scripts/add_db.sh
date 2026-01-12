#!/bin/bash

# --- Path Configuration ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/functions.sh"

PANEL_DATA_DIR="/var/bash_panel/userdata"

echo -e "${CYAN}=== CREATE NEW DATABASE ===${NC}"

# --- Step 1: Select Owner (System User) ---
if [ ! -d "$PANEL_DATA_DIR" ] || [ -z "$(ls -A "$PANEL_DATA_DIR")" ]; then
    error_exit "No users found. Create a user first."
fi

users=($(ls -1 "$PANEL_DATA_DIR"))

echo -e "\nSelect database owner:"
select username in "${users[@]}"; do
    [[ -n "$username" ]] && break || echo "Invalid selection."
done

# --- Step 2: Input Database Name ---
echo -e "\nEnter database name (prefix '${username}_' will be added automatically):"
read -p "Name: ${username}_" db_suffix
db_suffix=$(echo "$db_suffix" | tr -d '[:space:]')

[[ -z "$db_suffix" ]] && error_exit "Database name cannot be empty."

DB_NAME="${username}_${db_suffix}"
DB_USER="${username}_${db_suffix}" # User is the same as DB name as requested

# Check name length (MySQL users are limited to 32 characters)
if [ ${#DB_USER} -gt 32 ]; then
    error_exit "Resulting username '$DB_USER' is too long (max 32 chars)."
fi

# --- Step 3: Password Generation ---
DB_PASS=$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9' | head -c 16)

# --- Step 4: Create Database and User ---
log "Creating database and user: $DB_NAME..."

# SQL query with the defined privileges list
# Using localhost as websites usually reside on the same server
mysql <<EOF
CREATE DATABASE \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT ALTER, ALTER ROUTINE, CREATE, CREATE ROUTINE, CREATE TEMPORARY TABLES, 
      CREATE VIEW, DELETE, DROP, EVENT, EXECUTE, INDEX, INSERT, LOCK TABLES, 
      REFERENCES, SELECT, SHOW VIEW, TRIGGER, UPDATE 
      ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
EOF

if [ $? -eq 0 ]; then
    # Save database details to user metadata
    echo "DB:$DB_NAME|USER:$DB_USER|PASS:$DB_PASS" >> "$PANEL_DATA_DIR/$username/databases.list"
    
    # --- Step 5: Final Summary ---
    echo -e "\n${GREEN}##############################################################################${NC}"
    echo -e "${GREEN}      DATABASE CREATED SUCCESSFULLY        ${NC}"
    echo -e "Owner:          ${YELLOW}$username${NC}"
    echo -e "Database Name:  ${YELLOW}$DB_NAME${NC}"
    echo -e "Database User:  ${YELLOW}$DB_USER${NC}"
    echo -e "Password:       ${YELLOW}$DB_PASS${NC}"
    echo -e "Host:           ${YELLOW}localhost${NC}"
    echo -e "Privileges:     ${CYAN}Standard (Web App Set)${NC}"
    echo -e "${GREEN}##############################################################################${NC}"
else
    error_exit "Failed to create database. Check if it already exists."
fi
