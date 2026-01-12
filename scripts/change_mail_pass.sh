#!/bin/bash
# [2026-01-09] Using English for comments as requested
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/functions.sh"

PANEL_DATA_DIR="/var/bash_panel/userdata"
MAIL_USERS_FILE="/var/bash_panel/mail_users"

echo -e "${CYAN}=== CHANGE MAILBOX PASSWORD ===${NC}"

# --- Step 1: Selection (Owner & Email) ---
users=($(ls -1 "$PANEL_DATA_DIR" 2>/dev/null))
select username in "${users[@]}"; do [[ -n "$username" ]] && break; done

user_mailboxes=($(grep ":/home/$username/mail/" "$MAIL_USERS_FILE" | cut -d':' -f1))
select email in "${user_mailboxes[@]}"; do [[ -n "$email" ]] && break; done

# --- Step 2: Password ---
echo -ne "${YELLOW}Enter new password (empty for auto): ${NC}"
read -s password
echo ""
if [[ -z "$password" ]]; then
    password=$(openssl rand -base64 12)
    is_generated=true
else
    is_generated=false
fi

# --- Step 3: Hashing (The Fix) ---
# Generate salt (8 random chars)
salt=$(openssl rand -hex 4)
# Create SHA512 hash using openssl directly for better compatibility
new_hash=$(printf "$password" | openssl passwd -6 -stdin -salt "$salt")

# --- Step 4: Update File ---
current_line=$(grep "^$email:" "$MAIL_USERS_FILE")
# We keep fields 3-7 (UID, GID, etc.)
tail_part=$(echo "$current_line" | cut -d':' -f3-7)
# Important: We store hash WITHOUT {SHA512-CRYPT} prefix to avoid double-prefixing
new_line="$email:$new_hash:$tail_part"

sed -i "s|^$email:.*|$new_line|" "$MAIL_USERS_FILE"
chown vmail:vmail "$MAIL_USERS_FILE"
chmod 660 "$MAIL_USERS_FILE"

# --- Step 5: Summary ---
echo -e "\n${GREEN}=== PASSWORD UPDATE SUMMARY ===${NC}"
echo -e "Email: $email"
[[ "$is_generated" = true ]] && echo -e "Password: ${YELLOW}$password${NC}"
echo -e "Status: Updated"
