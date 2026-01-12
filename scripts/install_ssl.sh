#!/bin/bash

# --- Path Configuration ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/functions.sh"

PANEL_DATA_DIR="/var/bash_panel/userdata"

echo -e "${CYAN}=== SSL CERTIFICATE INSTALLER (Let's Encrypt) ===${NC}"

# --- Step 0: Dependency Check ---
check_ssl_requirements() {
    local missing_pkgs=()
    ! command -v certbot &> /dev/null && missing_pkgs+=("certbot")
    ! rpm -q python3-certbot-nginx &> /dev/null && missing_pkgs+=("python3-certbot-nginx")

    if [ ${#missing_pkgs[@]} -ne 0 ]; then
        log "Installing missing dependencies: ${missing_pkgs[*]}..."
        dnf install -y epel-release && dnf install -y "${missing_pkgs[@]}"
    fi
}
check_ssl_requirements

# --- Step 1: Select Owner ---
users=($(ls -1 "$PANEL_DATA_DIR" 2>/dev/null))
[[ ${#users[@]} -eq 0 ]] && error_exit "No users found."

echo "Select website owner:"
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

echo "Select domain for SSL:"
select domain in "${domains[@]}"; do
    [[ -n "$domain" ]] && break || echo "Invalid selection."
done

# --- Step 3: DNS Validation (A-Record check) ---
log "Checking DNS for $domain..."
SERVER_IP=$(curl -s --connect-timeout 5 https://api.ipify.org)
DOMAIN_IP=$(dig +short "$domain" | tail -n1)

if [ "$DOMAIN_IP" != "$SERVER_IP" ]; then
    warn "Domain $domain points to $DOMAIN_IP, but this server is $SERVER_IP."
    read -p "DNS may not be ready. Certbot might fail. Continue? (y/N): " dns_confirm
    [[ ! $dns_confirm =~ ^[Yy]$ ]] && exit 0
fi

# --- Step 4: Run Certbot ---
log "Requesting SSL from Let's Encrypt for $domain and www.$domain..."

certbot --nginx -d "$domain" -d "www.$domain" --non-interactive --agree-tos --register-unsafely-without-email

if [ $? -eq 0 ]; then
    log "SSL installed successfully for $domain!"
    
    # Update SSL status flag in user's domains.list
    sed -i "s/|$domain|/|$domain|SSL:YES|/" "$USER_DOMAINS_FILE"
    
    # Setup auto-renewal cron job (if not already present)
    if ! crontab -l 2>/dev/null | grep -q "certbot renew"; then
        (crontab -l 2>/dev/null; echo "0 0,12 * * * certbot renew -q") | crontab -
        log "Auto-renewal cron job added."
    fi
else
    error_exit "Certbot failed. Check /var/log/letsencrypt/letsencrypt.log"
fi

echo -e "\n${GREEN}##############################################################################${NC}"
echo -e "      HTTPS is now active for https://$domain"
echo -e "##############################################################################${NC}"
