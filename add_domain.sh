#!/bin/bash

# --- Get script and template directories ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TPL_DIR="$SCRIPT_DIR/templates"

# --- Include external functions ---
source "$SCRIPT_DIR/functions.sh"

# --- Global Config ---
PANEL_DATA_DIR="/var/bash_panel/userdata"
GLOBAL_DOMAINS_FILE="/var/bash_panel/global_domains.list"

echo -e "${CYAN}=== ADD NEW DOMAIN ===${NC}"

# --- Крок 1: Перевірка наявності користувачів та вибір ---
if [ ! -d "$PANEL_DATA_DIR" ] || [ -z "$(ls -A "$PANEL_DATA_DIR")" ]; then
    error_exit "No users found in $PANEL_DATA_DIR. Please create a user first using add_user.sh"
fi

users=($(ls -1 "$PANEL_DATA_DIR"))

echo -e "\nSelect a user (owner of the domain):"
select username in "${users[@]}"; do
    if [[ -n "$username" ]]; then
        log "Selected user: $username"
        break
    else
        echo -e "${RED}Invalid selection. Please choose a number from the list.${NC}"
    fi
done

# --- Крок 2: Виявлення IP сервера ---
log "Detecting server IP address..."
SERVER_IP=$(curl -s --connect-timeout 5 https://api.ipify.org || hostname -I | awk '{print $1}')
[[ -z "$SERVER_IP" ]] && error_exit "Could not detect server IP address."

# --- Крок 3: Введення домену та перевірка ---
read -p "Enter Domain Name (e.g., example.com): " domain
domain=$(echo "$domain" | tr '[:upper:]' '[:lower:]' | xargs)

[[ -z "$domain" ]] && error_exit "Domain name cannot be empty."

if grep -q "^$domain:" "$GLOBAL_DOMAINS_FILE" 2>/dev/null; then
    error_exit "Domain $domain is already hosted on this server."
fi

# --- Крок 4: Вибір версії PHP ---
echo -e "\nSelect PHP Version for $domain:"
php_versions=("7.4" "8.1" "8.2" "8.3")
select php_ver in "${php_versions[@]}"; do
    if [ -n "$php_ver" ]; then
        v_nodot=$(echo $php_ver | sed 's/\.//')
        PHP_SVC="php${v_nodot}-php-fpm"
        PHP_SOCK="/var/opt/remi/php${v_nodot}/run/php-fpm/${domain}.sock"
        break
    else
        echo -e "${RED}Invalid selection. Please choose 1-4.${NC}"
    fi
done

# --- Крок 5: Створення PHP-пулу з шаблону ---
POOL_CONF="/etc/opt/remi/php${v_nodot}/php-fpm.d/${domain}.conf"
if [ -f "$TPL_DIR/php_pool.tpl" ]; then
    log "Generating isolated PHP-FPM pool..."
    cp "$TPL_DIR/php_pool.tpl" "$POOL_CONF"
    sed -i "s/{{DOMAIN}}/$domain/g" "$POOL_CONF"
    sed -i "s/{{USER}}/$username/g" "$POOL_CONF"
    sed -i "s|{{PHP_SOCK}}|$PHP_SOCK|g" "$POOL_CONF"
else
    error_exit "Template $TPL_DIR/php_pool.tpl not found!"
fi

# --- Крок 6: Налаштування директорій ---
USER_DOMAIN_DIR="/home/$username/domains/$domain"
log "Creating directory: $USER_DOMAIN_DIR"
mkdir -p "$USER_DOMAIN_DIR"
chown $username:$username "$USER_DOMAIN_DIR"
chmod 755 "$USER_DOMAIN_DIR"

# --- Крок 7: Генерація Nginx Vhost ---
log "Generating Nginx config..."
CONF_FILE="/etc/nginx/conf.d/$domain.conf"
if [ -f "$TPL_DIR/nginx.tpl" ]; then
    cp "$TPL_DIR/nginx.tpl" "$CONF_FILE"
    sed -i "s/{{DOMAIN}}/$domain/g" "$CONF_FILE"
    sed -i "s/{{USER}}/$username/g" "$CONF_FILE"
    sed -i "s/{{SERVER_IP}}/$SERVER_IP/g" "$CONF_FILE"
    sed -i "s|{{PHP_SOCK}}|$PHP_SOCK|g" "$CONF_FILE"
else
    error_exit "Nginx template missing at $TPL_DIR/nginx.tpl"
fi

# --- Крок 8: Налаштування BIND DNS ---
log "Configuring DNS..."
ZONE_FILE="/var/named/$domain.db"
SERIAL=$(date +%Y%m%d%H)

if [ -f "$TPL_DIR/bind.tpl" ]; then
    cp "$TPL_DIR/bind.tpl" "$ZONE_FILE"
    sed -i "s/{{DOMAIN}}/$domain/g" "$ZONE_FILE"
    sed -i "s/{{SERVER_IP}}/$SERVER_IP/g" "$ZONE_FILE"
    sed -i "s/{{SERIAL}}/$SERIAL/g" "$ZONE_FILE"
    chown named:named "$ZONE_FILE"
fi

if ! grep -q "zone \"$domain\"" /etc/named.conf; then
    echo "" >> /etc/named.conf
    sed "s/{{DOMAIN}}/$domain/g" "$TPL_DIR/named_zone.tpl" >> /etc/named.conf
    echo "" >> /etc/named.conf
fi

# --- Крок 9: Деплой вітальної сторінки ---
if [ -f "$TPL_DIR/index.php" ]; then
    cp "$TPL_DIR/index.php" "$USER_DOMAIN_DIR/index.php"
    sed -i "s/{{DOMAIN}}/$domain/g" "$USER_DOMAIN_DIR/index.php"
    chown $username:$username "$USER_DOMAIN_DIR/index.php"
fi

# --- Крок 10: Метадані та перезапуск сервісів ---
echo "$domain:$username" >> "$GLOBAL_DOMAINS_FILE"
echo "$domain|PHP:$php_ver|V_NODOT:$v_nodot|IP:$SERVER_IP" >> "$PANEL_DATA_DIR/$username/domains.list"

log "Restarting $PHP_SVC, Nginx and BIND..."
systemctl restart "$PHP_SVC"
nginx -t && systemctl reload nginx
rndc reload || systemctl reload named

# --- ФІНАЛЬНИЙ ЗВІТ (SUMMARY) ---
echo -e "\n${GREEN}##############################################################################${NC}"
echo -e "${GREEN}      DOMAIN $domain ADDED SUCCESSFULLY        ${NC}"
echo -e "Owner:          ${YELLOW}$username${NC}"
echo -e "IP:             ${YELLOW}$SERVER_IP${NC}"
echo -e "PHP Version:    ${YELLOW}$php_ver${NC}"
echo -e "PHP Config:     ${YELLOW}$POOL_CONF${NC}"
echo -e "Root Directory: ${YELLOW}$USER_DOMAIN_DIR${NC}"
echo -e "Nginx Config:   ${YELLOW}$CONF_FILE${NC}"
echo -e "DNS Zone File:  ${YELLOW}$ZONE_FILE${NC}"
echo -e "${GREEN}##############################################################################${NC}"
