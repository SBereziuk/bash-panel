#!/bin/bash

# --- Include global settings ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/functions.sh"

PANEL_DATA_DIR="/var/bash_panel/userdata"

echo -e "${CYAN}=== MANAGE SSH ACCESS ===${NC}"

# --- Step 1: Select User ---
if [ ! -d "$PANEL_DATA_DIR" ] || [ -z "$(ls -A "$PANEL_DATA_DIR")" ]; then
    error_exit "No users found."
fi

users=($(ls -1 "$PANEL_DATA_DIR"))

echo -e "\nSelect user:"
select username in "${users[@]}"; do
    [[ -n "$username" ]] && break || echo "Invalid selection."
done

# --- Step 2: Check Current Status ---
# Check if user has a valid shell or nologin
current_shell=$(getent passwd "$username" | cut -d: -f7)

if [[ "$current_shell" == "/bin/bash" ]]; then
    status="${GREEN}ENABLED${NC}"
else
    status="${RED}DISABLED${NC}"
fi

echo -e "Current SSH status for $username: $status"

# --- Step 3: Toggle Access ---
echo -e "\nWhat would you like to do?"
options=("Enable SSH Access" "Disable SSH Access" "Cancel")
select opt in "${options[@]}"; do
    case $opt in
        "Enable SSH Access")
            # Set shell to bash
            usermod -s /bin/bash "$username"
            log "SSH access enabled for $username"
            break
            ;;
        "Disable SSH Access")
            # Set shell to nologin
            usermod -s /sbin/nologin "$username"
            log "SSH access disabled for $username"
            break
            ;;
        "Cancel")
            exit 0
            ;;
        *) echo "Invalid option";;
    esac
done

# --- Step 4: Security Note (Chroot) ---
# Note: For real chroot isolation, additional OpenSSH config is needed in /etc/ssh/sshd_config
echo -e "\n${YELLOW}NOTE:${NC} User is now restricted by their system shell permissions."
echo -e "To strictly jail users to /home/$username, ensure SSHD ChrootDirectory is configured."
