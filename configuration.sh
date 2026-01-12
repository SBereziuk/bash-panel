#!/bin/bash

# --- Include global settings ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/functions.sh"

echo -e "${CYAN}=== STARTING AUTOMATIC SYSTEM CONFIGURATION ===${NC}"

# 1. Create vmail user [2026-01-11]
if ! id "vmail" &>/dev/null; then
    log "Creating vmail user (UID 5000)..."
    groupadd -g 5000 vmail
    useradd -u 5000 -g vmail -s /usr/sbin/nologin -d /var/bash_panel/vmail -m vmail
else
    log "User vmail already exists."
fi

# Add dovecot to vmail group
usermod -aG vmail dovecot

# 2. Configure Dovecot
log "Configuring Dovecot..."
DOVECOT_CONF="/etc/dovecot/conf.d/10-auth.conf"
sed -i 's/^[[:space:]]*!include auth-system.conf.ext/#!include auth-system.conf.ext/' "$DOVECOT_CONF"
sed -i 's/^[[:space:]]*#!include auth-passwdfile.conf.ext/!include auth-passwdfile.conf.ext/' "$DOVECOT_CONF"

# Setup auth-passwdfile.conf.ext
cat <<EOF > /etc/dovecot/conf.d/auth-passwdfile.conf.ext
passdb {
  driver = passwd-file
  args = scheme=MD5-CRYPT username_format=%u /var/bash_panel/mail_users
}
userdb {
  driver = passwd-file
  args = username_format=%u /var/bash_panel/mail_users
}
EOF

# Setup master socket for Exim
cat <<EOF > /etc/dovecot/conf.d/10-master.conf
service auth {
  unix_listener auth-client {
    mode = 0660
    user = exim
    group = exim
  }
}
EOF

# 3. Configure Pure-FTPd
log "Configuring Pure-FTPd..."
mkdir -p /etc/pure-ftpd/conf
echo "no" > /etc/pure-ftpd/conf/PAMAuthentication
echo "no" > /etc/pure-ftpd/conf/UnixAuthentication
echo "/etc/pure-ftpd/pureftpd.pdb" > /etc/pure-ftpd/conf/PureDB

# 4. Configure Exim (Append authenticators if not present)
log "Configuring Exim authenticators..."
EXIM_CONF="/etc/exim/exim.conf"

if ! grep -q "dovecot_plain:" "$EXIM_CONF"; then
cat <<EOF >> "$EXIM_CONF"

######################################################################
#                      AUTHENTICATORS CONFIGURATION                  #
######################################################################
dovecot_plain:
  driver = dovecot
  public_name = PLAIN
  server_socket = /var/run/dovecot/auth-client
  server_set_id = \$auth1

dovecot_login:
  driver = dovecot
  public_name = LOGIN
  server_socket = /var/run/dovecot/auth-client
  server_set_id = \$auth1
EOF
fi

# 5. Finalize
touch /var/bash_panel/mail_users
chmod 644 /var/bash_panel/mail_users
chown root:root /var/bash_panel/mail_users

log "Restarting services..."
systemctl restart dovecot exim pure-ftpd

echo -e "\n${GREEN}##############################################################################${NC}"
echo -e "${GREEN}                SYSTEM CONFIGURED SUCCESSFULLY                                ${NC}"
echo -e "Services:       Dovecot, Exim, Pure-FTPd"
echo -e "Mail User:      vmail (5000:5000)"
echo -e "Auth File:      /var/bash_panel/mail_users"
echo -e "${GREEN}##############################################################################${NC}\n"
