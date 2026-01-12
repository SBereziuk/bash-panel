	#!/bin/bash

# --- Include external functions ---
source ./functions.sh

# --- Initial Environment Checks ---
check_root
check_os

INSTALL_MARKER="/root/.panel_installed"

# --- Check if installation was already performed ---
if [ -f "$INSTALL_MARKER" ]; then
    log "System is already configured. Launching the Management Menu..."
    exit 0
fi

clear
echo -e "${YELLOW}===============================================${NC}"
echo -e "${YELLOW}       BASH-PANEL INSTALLER (RHEL/ALMA)        ${NC}"
echo -e "${YELLOW}===============================================${NC}"

# --- Step 1: User Requirements Gathering ---

# Web Server Choice
echo -e "\n${YELLOW}[Step 1] Choose Web Server Stack:${NC}"
PS3='Select (1-3): '
select web in "NGINX" "Apache" "OpenLiteSpeed"; do
    case $web in
        NGINX) WEB_PKG="nginx"; break;;
        Apache) WEB_PKG="httpd"; break;;
        OpenLiteSpeed) WEB_PKG="openlitespeed"; break;;
    esac
done

# Database Server Choice
echo -e "\n${YELLOW}[Step 2] Choose Database Engine:${NC}"
select db in "MariaDB" "MySQL" "PostgreSQL"; do
    case $db in
        MariaDB) DB_PKG="mariadb-server"; break;;
        MySQL) DB_PKG="mysql-server"; break;;
        PostgreSQL) DB_PKG="postgresql-server"; break;;
    esac
done

# DNS Server Choice
echo -e "\n${YELLOW}[Step 3] Choose DNS Server:${NC}"
select dns in "BIND" "PowerDNS" "None"; do
    case $dns in
        BIND) DNS_PKG="bind bind-utils"; DNS_SVC="named"; break;;
        PowerDNS) DNS_PKG="pdns pdns-backend-mysql"; DNS_SVC="pdns"; break;;
        *) DNS_PKG=""; break;;
    esac
done

# --- Step 4: Cache Service Selection ---

echo -e "\n${YELLOW}[Step 4] Choose Cache Service:${NC}"
PS3='Select (1-3): '
select cache_opt in "Redis" "Memcached" "Not Needed"; do
    case $cache_opt in
        "Redis")
            INSTALL_REDIS=true
            INSTALL_MEMCACHED=false
            break
            ;;
        "Memcached")
            INSTALL_REDIS=false
            INSTALL_MEMCACHED=true
            break
            ;;
        "Not Needed")
            INSTALL_REDIS=false
            INSTALL_MEMCACHED=false
            break
            ;;
        *) echo "Invalid option $REPLY";;
    esac
done


# --- Step 2: Summary and Confirmation ---

clear
echo -e "${YELLOW}===============================================${NC}"
echo -e "${YELLOW}       INSTALLATION SUMMARY & CONFIRM          ${NC}"
echo -e "${YELLOW}===============================================${NC}"
echo -e "The following stack will be installed:"
echo -e "  - Web Server:      ${GREEN}$web${NC}"
echo -e "  - DB Server:       ${GREEN}$db${NC}"
echo -e "  - DNS Server:      ${GREEN}$dns${NC}"
echo -e "  - Multi-PHP:       ${GREEN}7.4, 8.1, 8.2, 8.3 (Remi)${NC}"
echo -e "  - Mail Stack:      ${GREEN}Exim + Dovecot${NC}"
echo -e "  - FTP Server:      ${GREEN}Pure-FTPd${NC}"
echo -e "  - Security:        ${GREEN}CSF Firewall, Certbot (SSL)${NC}"
echo -e "  - Cache:           ${GREEN}Redis ($INSTALL_REDIS), Memcached ($INSTALL_MEMCACHED)${NC}"
echo -e "  - Monitoring:      ${GREEN}Monit${NC}"
echo -e "-----------------------------------------------"

PS3='Do you want to proceed? '
select confirm in "Confirm and Start Installation" "Exit and Cancel"; do
    case $confirm in
        "Confirm and Start Installation")
            log "Starting installation process..."
            break
            ;;
        "Exit and Cancel")
            log "Installation cancelled by user."
            exit 0
            ;;
        *) echo "Invalid option $REPLY";;
    esac
done

# --- Step 3: Repository & Core Package Installation ---

log "Detecting OS version and installing Repositories..."
OS_VER=$(grep -oP '(?<=^VERSION_ID=").*(?=")' /etc/os-release | cut -d. -f1)

dnf update -y
dnf install -y epel-release dnf-utils

if [ "$OS_VER" == "9" ]; then
    dnf install -y https://rpms.remirepo.net/enterprise/remi-release-9.rpm
else
    dnf install -y https://rpms.remirepo.net/enterprise/remi-release-8.rpm
fi

log "Installing system core utilities (Quota, Monit, Logrotate, Cron, Certbot)..."
dnf install -y quota monit logrotate crontabs wget curl git htop openssh-server certbot

# --- Step 4: Service Deployment ---

log "Deploying Web Server: $web..."
if [ "$web" == "OpenLiteSpeed" ]; then
    rpm -Uvh http://rpms.litespeedtech.com/centos/litemsw-repo-1.0-1.noarch.rpm
    dnf install -y openlitespeed
    systemctl enable --now lsws
else
    dnf install -y $WEB_PKG
    systemctl enable --now $WEB_PKG
fi

log "Deploying Database Engine: $db..."
dnf install -y $DB_PKG
DB_SVC=${DB_PKG/-server/}
systemctl enable --now $DB_SVC

log "Deploying Multi-PHP Environment (7.4, 8.1, 8.2, 8.3)..."
for ver in 74 81 82 83; do
    log "Installing PHP $ver..."
    dnf install -y php${ver}-php-fpm php${ver}-php-cli php${ver}-php-mysqlnd php${ver}-php-gd php${ver}-php-mbstring php${ver}-php-xml php${ver}-php-opcache php${ver}-php-zip
    systemctl enable --now php${ver}-php-fpm
done

log "Deploying Mail Stack (Exim + Dovecot)..."
dnf install -y exim dovecot
systemctl enable --now exim dovecot

log "Deploying FTP Server (Pure-FTPd)..."
dnf install -y pure-ftpd
systemctl enable --now pure-ftpd

if [ ! -z "$DNS_PKG" ]; then
    log "Deploying DNS Server: $dns..."
    dnf install -y $DNS_PKG
    systemctl enable --now $DNS_SVC
fi

# Caching Services
if [ "$INSTALL_REDIS" = true ]; then
    log "Installing Redis..."
    dnf install -y redis
    systemctl enable --now redis
fi

if [ "$INSTALL_MEMCACHED" = true ]; then
    log "Installing Memcached..."
    dnf install -y memcached
    systemctl enable --now memcached
fi

# --- Step 5: Security Hardening (CSF Firewall) ---

log "Installing ConfigServer Security & Firewall (CSF)..."
cd /usr/src
wget https://download.configserver.dev/csf.tgz
tar -xzf csf.tgz
cd csf
sh install.sh
sed -i 's/TESTING = "1"/TESTING = "0"/' /etc/csf/csf.conf
csf -r

# --- Step 6: Finalization ---

touch $INSTALL_MARKER
log "PROVISIONING FINISHED SUCCESSFULLY"

