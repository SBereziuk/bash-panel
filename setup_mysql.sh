#!/bin/bash
source "/var/bash_panel/functions.sh"

# Генеруємо надійний пароль для root, якщо він не заданий
DB_ROOT_PASS=$(openssl rand -base64 16)

log "Securing MySQL installation..."

# Виконуємо запити для безпеки
mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASS}';"
mysql -e "DELETE FROM mysql.user WHERE User='';"
mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
mysql -e "DROP DATABASE IF EXISTS test;"
mysql -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
mysql -e "FLUSH PRIVILEGES;"

# Створюємо файл доступу для нашої панелі
cat <<EOF > /root/.my.cnf
[client]
user=root
password="${DB_ROOT_PASS}"
EOF

chmod 600 /root/.my.cnf

echo -e "${GREEN}MySQL secured successfully.${NC}"
echo -e "Root password saved in ${YELLOW}/root/.my.cnf${NC}"
