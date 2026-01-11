#!/bin/bash

# --- Include global settings ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/functions.sh"

PANEL_DATA_DIR="/var/bash_panel/userdata"
EXIM_DOMAINS="/etc/exim/domains"
MAIL_USERS_FILE="/var/bash_panel/mail_users"

echo -e "${RED}=== DISABLE MAIL FOR DOMAIN ===${NC}"

# --- Step 1: Select Owner ---
users=($(ls -1 "$PANEL_DATA_DIR" 2>/dev/null))
[[ ${#users[@]} -eq 0 ]] && error_exit "No users found."

echo "Select domain owner:"
select username in "${users[@]}"; do
    [[ -n "$username" ]] && break || echo "Invalid selection."
done

# --- Step 2: Select Domain from Exim list (Compatible version) ---
# We use a simple array population loop instead of mapfile
mail_domains=()
while IFS=: read -r dname owner; do
    # Remove leading/trailing whitespace from owner
    owner_trimmed=$(echo "$owner" | xargs)
    if [[ "$owner_trimmed" == "$username" ]]; then
        mail_domains+=("$dname")
    fi
done < "$EXIM_DOMAINS"

if [ ${#mail_domains[@]} -eq 0 ]; then
    error_exit "No mail-enabled domains found for user $username."
fi

echo -e "\nSelect domain to DISABLE mail:"
select domain in "${mail_domains[@]}"; do
    [[ -n "$domain" ]] && break || echo "Invalid selection."
done

# --- Step 3: Confirmation ---
read -p "DANGER! This will delete ALL mailboxes and messages for $domain. Proceed? (y/N): " confirm
[[ ! $confirm =~ ^[Yy]$ ]] && exit 0

# --- Step 4: Remove from Exim and Dovecot Auth ---
log "Removing domain from Exim configuration..."
# Escaping dots in domain for sed
escaped_domain=$(echo "$domain" | sed 's/\./\\./g')
sed -i "/^$escaped_domain: $username/d" "$EXIM_DOMAINS"

log "Removing all virtual accounts for $domain from auth file..."
sed -i "/@$escaped_domain/d" "$MAIL_USERS_FILE"

# --- Step 5: Delete Mail Files ---
MAIL_ROOT="/home/$username/mail/$domain"
if [ -d "$MAIL_ROOT" ]; then
    log "Deleting physical mail files in $MAIL_ROOT..."
    rm -rf "$MAIL_ROOT"
fi

# --- Step 6: Cleanup DNS (MX and SPF) ---
ZONE_FILE="/var/named/$domain.db"
if [ -f "$ZONE_FILE" ]; then
    log "Removing MX and SPF records from DNS..."
    sed -i '/IN MX/d' "$ZONE_FILE"
    sed -i '/v=spf1/d' "$ZONE_FILE"
    
    # Update Serial
    sed -i "s/[0-9]\{10\}/$(date +%Y%m%d%H)/" "$ZONE_FILE"
    rndc reload "$domain" > /dev/null 2>&1
fi

# --- Step 7: Restart Services ---
systemctl restart exim dovecot

echo -e "\n${GREEN}DONE: Mail service for $domain is disabled.${NC}"
