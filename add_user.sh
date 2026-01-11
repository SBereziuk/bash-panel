#!/bin/bash

# --- Include external functions ---
source ./functions.sh

# --- Check for Root ---
check_root

# --- Global Config ---
PANEL_DATA_DIR="/var/bash_panel/userdata"

echo -e "${YELLOW}===============================================${NC}"
echo -e "${YELLOW}       CREATE NEW SYSTEM USER (HOSTING)        ${NC}"
echo -e "${YELLOW}===============================================${NC}"

# --- Step 1: Collect User Data ---
read -p "Enter Username (lowercase, no spaces): " username

# Validation: Check if user already exists in system
if id "$username" &>/dev/null; then
    error_exit "User $username already exists in the system!"
fi

# Password generation
password=$(openssl rand -base64 12)

# --- Step 2: System User Creation ---
log "Creating system user: $username..."
# Create user with a non-interactive shell for security
useradd -m -s /sbin/nologin $username
echo "$username:$password" | chpasswd

# --- Step 3: Directory Structure Creation ---
log "Setting up directory structure in /home..."

USER_HOME="/home/$username"
# domains/ for site files, logs/ for web logs, tmp/ for sessions/uploads
DIRS=("$USER_HOME/domains" "$USER_HOME/logs" "$USER_HOME/tmp")

for dir in "${DIRS[@]}"; do
    mkdir -p "$dir"
    chown $username:$username "$dir"
    chmod 755 "$dir"
done

# Restrict home directory access (security hardening)
chmod 711 "$USER_HOME"

# --- Step 4: Metadata Storage ---
log "Saving user metadata to $PANEL_DATA_DIR/$username..."

# Create panel metadata directory if not exists
mkdir -p "$PANEL_DATA_DIR/$username"

# Create a simple config file with user details
cat <<EOF > "$PANEL_DATA_DIR/$username/info.conf"
# Bash-Panel User Metadata
USER_NAME="$username"
USER_PASS="$password"
CREATED_AT="$(date +'%Y-%m-%d %H:%M:%S')"
HOME_DIR="$USER_HOME"
QUOTA_LIMIT="5GB"
STATUS="active"
EOF

# Ensure only root can read metadata
chmod 600 "$PANEL_DATA_DIR/$username/info.conf"

# --- Summary ---
echo -e "\n${GREEN}###############################################${NC}"
echo -e "${GREEN}      USER ACCOUNT CREATED SUCCESSFULLY        ${NC}"
echo -e "${GREEN}###############################################${NC}"
echo -e "Username:    ${YELLOW}$username${NC}"
echo -e "Password:    ${YELLOW}$password${NC}"
echo -e "Metadata:    ${YELLOW}$PANEL_DATA_DIR/$username/info.conf${NC}"
echo -e "-----------------------------------------------"
log "Note: Use add_domain.sh to create virtual hosts for this user."
