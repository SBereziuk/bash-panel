#!/bin/bash

# --- Include external functions ---
source ./functions.sh

# --- Initial Environment Checks ---
check_root

clear
echo -e "${RED}===============================================${NC}"
echo -e "${RED}       BASH-PANEL UNINSTALLER (DANGER)         ${NC}"
echo -e "${RED}===============================================${NC}"
echo -e "This script will remove all installed services, configs, and data."
echo -e "Target OS: AlmaLinux/RHEL"
echo -e "-----------------------------------------------"

# --- Confirmation ---
read -p "Are you absolutely sure you want to uninstall everything? (y/N): " confirm
if [[ ! $confirm =~ ^[Yy]$ ]]; then
    log "Uninstallation cancelled."
    exit 0
fi

# --- Step 1: Stop and Disable Services ---
log "Stopping all panel-related services..."

# List of possible services to stop
SERVICES=(
    "nginx" "httpd" "lsws" 
    "mariadb" "mysqld" "postgresql" 
    "php74-php-fpm" "php81-php-fpm" "php82-php-fpm" "php83-php-fpm"
    "exim" "dovecot" "pure-ftpd" "named" "pdns"
    "redis" "memcached" "monit"
)

for svc in "${SERVICES[@]}"; do
    if systemctl is-active --quiet $svc; then
        log "Stopping $svc..."
        systemctl stop $svc
        systemctl disable $svc
    fi
done

# --- Step 2: Remove Packages ---
log "Removing packages via DNF..."

# Web servers
dnf remove -y nginx httpd openlitespeed
# Databases
dnf remove -y mariadb-server mariadb mysql-server mysql postgresql-server
# PHP versions
dnf remove -y php74-php* php81-php* php82-php* php83-php*
# Mail & FTP
dnf remove -y exim dovecot pure-ftpd
# DNS
dnf remove -y bind pdns pdns-backend-mysql
# Caching & Tools
dnf remove -y redis memcached monit certbot quota

dnf autoremove -y
dnf clean all

# --- Step 3: Remove CSF Firewall ---
if [ -d "/etc/csf" ]; then
    log "Removing CSF Firewall..."
    cd /etc/csf
    sh uninstall.sh
    cd /root
fi

# --- Step 4: Delete Configuration Directories & Data ---
log "Cleaning up configuration files and web data..."

DIRS=(
    "/etc/nginx" "/etc/httpd" "/usr/local/lsws"
    "/etc/opt/remi" "/var/opt/remi"
    "/var/lib/mysql" "/var/lib/pgsql"
    "/etc/exim" "/etc/dovecot" "/etc/pure-ftpd"
    "/var/www" "/home/*/public_html"
    "/etc/monit.d" "/etc/logrotate.d/my_panel"
)

for dir in "${DIRS[@]}"; do
    if [ -d "$dir" ] || [ -e "$dir" ]; then
        log "Deleting $dir..."
        rm -rf $dir
    fi
done

# --- Step 5: Final Cleanup ---
log "Removing installation marker and temporary files..."
rm -f /root/.panel_installed
rm -rf /usr/src/csf*

log "UNINSTALLATION COMPLETED."
echo -e "${YELLOW}Note: Some system dependencies might remain. For a 100% clean state, a OS reinstall is recommended.${NC}"
echo -e "${YELLOW}System reboot is advised.${NC}"
