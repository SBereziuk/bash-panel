#!/bin/bash

# --- Include global settings ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/functions.sh"

PANEL_DATA_DIR="/var/bash_panel/userdata"
EXIM_DOMAINS="/etc/exim/domains"

echo -e "${CYAN}=== ENABLE MAIL FOR DOMAIN ===${NC}"

# --- Step 1: Select Owner ---
users=($(ls -1 "$PANEL_DATA_DIR" 2>/dev/null))
[[ ${#users[@]} -eq 0 ]] && error_exit "No users found."

echo "Select domain owner:"
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

echo -e "\nSelect domain:"
select domain in "${domains[@]}"; do
    [[ -n "$domain" ]] && break || echo "Invalid selection."
done

# --- Step 3: Check/Create vmail group ---
if ! getent group vmail > /dev/null; then
    log "Group 'vmail' not found. Creating with GID 5000..."
    groupadd -g 5000 vmail
fi

# --- Step 4: Create & Fix Permissions ---
MAIL_ROOT="/home/$username/mail"
DOMAIN_PATH="$MAIL_ROOT/$domain"

log "Creating $DOMAIN_PATH..."
mkdir -p "$DOMAIN_PATH"

log "Applying ownership $username:vmail..."
# Тепер група точно існує, тому chown спрацює
chown -R "$username:vmail" "$MAIL_ROOT"
chmod -R 770 "$MAIL_ROOT"

# --- Step 5: Register Domain in Exim ---
log "Registering domain in Exim..."
if ! grep -q "^$domain:" "$EXIM_DOMAINS" 2>/dev/null; then
    echo "$domain: $username" >> "$EXIM_DOMAINS"
fi

# --- Step 6: Update DNS (MX and SPF) ---
ZONE_FILE="/var/named/$domain.db"
if [ -f "$ZONE_FILE" ]; then
    log "Updating DNS records..."
    sed -i '/IN MX/d' "$ZONE_FILE"
    sed -i '/v=spf1/d' "$ZONE_FILE"
    echo "@    IN    MX    10    $domain." >> "$ZONE_FILE"
    SERVER_IP=$(hostname -I | awk '{print $1}')
    echo "@    IN    TXT   \"v=spf1 a mx ip4:$SERVER_IP ~all\"" >> "$ZONE_FILE"
    sed -i "s/[0-9]\{10\}/$(date +%Y%m%d%H)/" "$ZONE_FILE"
    rndc reload "$domain" > /dev/null 2>&1
fi

systemctl restart exim

final_check=$(ls -ld "$MAIL_ROOT")
echo -e "\n${GREEN}SUCCESS: Mail enabled for $domain.${NC}"
echo -e "Permissions: ${YELLOW}$final_check${NC}"
