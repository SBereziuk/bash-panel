#!/bin/bash

# --- Include global settings ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/functions.sh"

PANEL_DATA_DIR="/var/bash_panel/userdata"
GLOBAL_DOMAINS_FILE="/var/bash_panel/global_domains.list"

echo -e "${RED}=== TOTAL USER DESTRUCTION (WITH FTP & DB) ===${NC}"

# --- Step 1: Select User ---
users=($(ls -1 "$PANEL_DATA_DIR" 2>/dev/null))
[[ ${#users[@]} -eq 0 ]] && error_exit "No users found."

echo "Select user to DELETE COMPLETELY:"
select username in "${users[@]}"; do
    [[ -n "$username" ]] && break || echo "Invalid selection."
done

read -p "DANGER! This will delete ALL domains, files, databases and FTP accounts for $username. Proceed? (y/N): " confirm
[[ ! $confirm =~ ^[Yy]$ ]] && exit 0

# --- Step 2: Remove FTP Accounts (NEW) ---
FTP_LIST_FILE="$PANEL_DATA_DIR/$username/ftp_users.list"
if [ -s "$FTP_LIST_FILE" ]; then
    log "Removing virtual FTP accounts for $username..."
    while IFS='|' read -r ftp_info _; do
        ftp_login=$(echo "$ftp_info" | cut -d':' -f2 | cut -d'|' -f1)
        if [ -n "$ftp_login" ]; then
            log "  - Removing FTP user: $ftp_login"
            pure-pw userdel "$ftp_login"
        fi
    done < "$FTP_LIST_FILE"
    pure-pw mkdb
fi

# --- Step 3: Remove Databases (MySQL) ---
DB_LIST_FILE="$PANEL_DATA_DIR/$username/databases.list"
if [ -s "$DB_LIST_FILE" ]; then
    log "Removing MySQL databases and users for $username..."
    while IFS='|' read -r db_info _; do
        db_name=$(echo "$db_info" | cut -d':' -f2 | cut -d'|' -f1)
        if [ -n "$db_name" ]; then
            log "  - Dropping DB/User: $db_name"
            mysql <<EOF
DROP DATABASE IF EXISTS \`${db_name}\`;
DROP USER IF EXISTS '${db_name}'@'localhost';
EOF
        fi
    done < "$DB_LIST_FILE"
    mysql -e "FLUSH PRIVILEGES;"
fi

# --- Step 4: Cleanup Domains (Nginx, DNS, SSL) ---
USER_DOMAINS_FILE="$PANEL_DATA_DIR/$username/domains.list"
if [ -s "$USER_DOMAINS_FILE" ]; then
    log "Cleaning up domains and DNS configs..."
    while IFS='|' read -r domain _; do
        [ -z "$domain" ] && continue
        log "  - Processing: $domain"
        rm -f "/etc/nginx/conf.d/$domain.conf"
        rm -f "/var/named/$domain.db"
        
        # Remove zone from named.conf
        LINE_NUM=$(grep -n "zone \"$domain\"" /etc/named.conf | cut -d: -f1)
        if [ -n "$LINE_NUM" ]; then
            END_LINE=$((LINE_NUM + 4))
            sed -i "${LINE_NUM},${END_LINE}d" /etc/named.conf
        fi
        sed -i "/^$domain:/d" "$GLOBAL_DOMAINS_FILE"
    done < "$USER_DOMAINS_FILE"
fi

# --- Step 5: Cleanup PHP Pools ---
log "Removing PHP-FPM pools..."
FILES_TO_REMOVE=$(grep -lR "user = $username" /etc/opt/remi/php*/php-fpm.d/ 2>/dev/null)
if [ -n "$FILES_TO_REMOVE" ]; then
    rm -f $FILES_TO_REMOVE
    systemctl restart php74-php-fpm php81-php-fpm php82-php-fpm php83-php-fpm 2>/dev/null
fi

# --- Step 6: System User and Files ---
log "Deleting system user $username and files..."
userdel -r "$username" 2>/dev/null
rm -rf "/home/$username"
rm -rf "$PANEL_DATA_DIR/$username"

# --- Step 7: Reload Services ---
log "Reloading Nginx and Named..."
nginx -t && systemctl reload nginx
rndc reload || systemctl reload named

log "SUCCESS: User $username and all associated resources removed."
