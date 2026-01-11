#!/bin/bash

# --- Include global settings ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/functions.sh"

PANEL_DATA_DIR="/var/bash_panel/userdata"
MAIL_USERS_FILE="/var/bash_panel/mail_users"
EXIM_DOMAINS="/etc/exim/domains"

echo -e "${CYAN}=== CREATE MAIL ACCOUNT ===${NC}"

# --- Step 1: Select Owner ---
users=($(ls -1 "$PANEL_DATA_DIR" 2>/dev/null))
[[ ${#users[@]} -eq 0 ]] && error_exit "No users found."

echo "Select account owner:"
select username in "${users[@]}"; do
    [[ -n "$username" ]] && break || echo "Invalid selection."
done

# --- Step 2: Select Mail-Enabled Domain ---
mail_domains=()
while IFS=: read -r dname owner; do
    owner_trimmed=$(echo "$owner" | xargs)
    if [[ "$owner_trimmed" == "$username" ]]; then
        mail_domains+=("$dname")
    fi
done < "$EXIM_DOMAINS"

[[ ${#mail_domains[@]} -eq 0 ]] && error_exit "No mail domains found for $username."

echo -e "\nSelect domain:"
select domain in "${mail_domains[@]}"; do
    [[ -n "$domain" ]] && break || echo "Invalid selection."
done

# --- Step 3: Account Details ---
read -p "Mail User (e.g. info): " mail_user
[[ -z "$mail_user" ]] && error_exit "Empty username."
full_email="${mail_user}@${domain}"

grep -q "^${full_email}:" "$MAIL_USERS_FILE" 2>/dev/null && error_exit "Account exists."

read -s -p "Enter password (empty for random): " mail_pass
echo ""
[[ -z "$mail_pass" ]] && mail_pass=$(openssl rand -base64 12 | tr -dc 'a-zA-Z0-9' | head -c 12) && echo "Pass: $mail_pass"

# --- Step 4: Hash Password ---
pass_hash=$(doveadm pw -s SHA512-CRYPT -p "$mail_pass")

# --- Step 5: Create Maildir (Owned by User) ---
# Path: /home/username/mail/domain/user
MAIL_ROOT="/home/$username/mail"
DOMAIN_PATH="$MAIL_ROOT/$domain"
ACC_PATH="$DOMAIN_PATH/$mail_user"

log "Creating storage for $full_email..."

# Create directories as root first
mkdir -p "$ACC_PATH"/{cur,new,tmp}

# Set ownership to the system user and vmail group
# This allows the user to see disk usage and vmail to write letters
chown -R "$username:vmail" "$MAIL_ROOT"
chmod -R 770 "$MAIL_ROOT"

# --- Step 6: Save to Auth File ---
# We still use UID 5000 (vmail) for the service to manage files
echo "${full_email}:${pass_hash}:5000:5000::${ACC_PATH}:/sbin/nologin" >> "$MAIL_USERS_FILE"

echo -e "\n${GREEN}Success! Account $full_email created and owned by $username.${NC}"
