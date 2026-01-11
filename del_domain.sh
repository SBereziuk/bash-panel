#!/bin/bash

# --- Get script directory ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/functions.sh"

# --- Global Config ---
PANEL_DATA_DIR="/var/bash_panel/userdata"
GLOBAL_DOMAINS_FILE="/var/bash_panel/global_domains.list"

echo -e "${RED}=== DELETE DOMAIN (Isolated Mode) ===${NC}"

# --- Step 1: Select User ---
users=($(ls -1 "$PANEL_DATA_DIR" 2>/dev/null))
[[ ${#users[@]} -eq 0 ]] && error_exit "No users found."

echo "Select owner:"
select username in "${users[@]}"; do
    [[ -n "$username" ]] && break || echo "Invalid selection."
done

# --- Step 2: Select Domain ---
USER_DOMAINS_FILE="$PANEL_DATA_DIR/$username/domains.list"
[[ ! -s "$USER_DOMAINS_FILE" ]] && error_exit "User has no domains."

domains=()
while IFS='|' read -r dname _; do
    [[ -n "$dname" ]] && domains+=("$dname")
done < "$USER_DOMAINS_FILE"

echo "Select domain to DELETE:"
select domain in "${domains[@]}"; do
    [[ -n "$domain" ]] && break || echo "Invalid selection."
done

# --- Step 3: Get PHP Version from Metadata ---
# Шукаємо рядок домену і витягуємо V_NODOT (наприклад, 83)
V_NODOT=$(grep "^$domain|" "$USER_DOMAINS_FILE" | awk -F'|V_NODOT:' '{print $2}' | awk -F'|' '{print $1}')
PHP_SVC="php${V_NODOT}-php-fpm"

read -p "Confirm deletion of $domain? (y/N): " confirm
[[ ! $confirm =~ ^[Yy]$ ]] && exit 0

# --- Step 4: Cleanup PHP Pool ---
POOL_CONF="/etc/opt/remi/php${V_NODOT}/php-fpm.d/${domain}.conf"
if [ -f "$POOL_CONF" ]; then
    log "Removing PHP pool config: $POOL_CONF"
    rm -f "$POOL_CONF"
    log "Restarting $PHP_SVC..."
    systemctl restart "$PHP_SVC"
else
    warn "PHP pool config not found for $domain."
fi

# --- Step 5: Cleanup Nginx ---
log "Removing Nginx config..."
rm -f "/etc/nginx/conf.d/$domain.conf"

# --- Step 6: Cleanup DNS (5 lines block) ---
log "Cleaning named.conf..."
LINE_NUM=$(grep -n "zone \"$domain\"" /etc/named.conf | cut -d: -f1)
if [ -n "$LINE_NUM" ]; then
    END_LINE=$((LINE_NUM + 4))
    sed -i "${LINE_NUM},${END_LINE}d" /etc/named.conf
    # Прибираємо зайві порожні рядки
    sed -i '/^$/N;/^\n$/D' /etc/named.conf
fi
rm -f "/var/named/$domain.db"

# --- Step 7: Cleanup Files & Metadata ---
log "Removing web files..."
rm -rf "/home/$username/domains/$domain"

log "Cleaning metadata..."
[[ -f "$GLOBAL_DOMAINS_FILE" ]] && sed -i "/^$domain:/d" "$GLOBAL_DOMAINS_FILE"
sed -i "/^$domain|/d" "$USER_DOMAINS_FILE"

# --- Step 8: Final Reload ---
log "Reloading Nginx and DNS..."
nginx -t && systemctl reload nginx
rndc reload || systemctl reload named

echo -e "\n${GREEN}Domain $domain and its PHP-FPM pool have been completely removed.${NC}"
