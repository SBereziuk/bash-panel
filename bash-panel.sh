#!/bin/bash

# --- Include global settings ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/scripts/functions.sh"

# Function to display the menu
show_menu() {
    clear
    echo -e "${CYAN}================================================================${NC}"
    echo -e "${CYAN}             BASH PANEL v1.0 - MAIN INTERFACE                 ${NC}"
    echo -e "${CYAN}================================================================${NC}"
    echo -e "${YELLOW}DATE:${NC} $(date +'%Y-%m-%d %H:%M:%S')   ${YELLOW}UPTIME:${NC} $(uptime -p)"
    echo -e "${CYAN}----------------------------------------------------------------${NC}"
    echo -e "  ${PURPLE}1)${NC} List All Resources (Overview)"
    echo -e "  ${PURPLE}2)${NC} Manage USERS (Add/Delete System User)"
    echo -e "  ${PURPLE}3)${NC} Manage DOMAINS (Add/Delete/SSL)"
    echo -e "  ${PURPLE}4)${NC} Manage DATABASES (MySQL)"
    echo -e "  ${PURPLE}5)${NC} Manage FTP Accounts"
    echo -e "  ${PURPLE}6)${NC} Manage MAIL (Domains & Mailboxes)"
    echo -e "  ${PURPLE}0)${NC} Exit"
    echo -e "${CYAN}----------------------------------------------------------------${NC}"
}

while true; do
    show_menu
    read -p "Select an option [0-6]: " choice

    case $choice in
        1)
            bash "$SCRIPT_DIR/scripts/list_all.sh"
            read -p "Press Enter to return to menu..."
            ;;
        2)
            echo -e "\n1) Add User\n2) Delete User\n3) Back"
            read -p "Option: " u_choice
            [[ "$u_choice" == "1" ]] && bash "$SCRIPT_DIR/scripts/add_user.sh"
            [[ "$u_choice" == "2" ]] && bash "$SCRIPT_DIR/scripts/del_user.sh"
            ;;
        3)
            echo -e "\n1) Add Domain\n2) Delete Domain\n3) Issue SSL (Let's Encrypt)\n4) Back"
            read -p "Option: " d_choice
            [[ "$d_choice" == "1" ]] && bash "$SCRIPT_DIR/scripts/add_domain.sh"
            [[ "$d_choice" == "2" ]] && bash "$SCRIPT_DIR/scripts/del_domain.sh"
            [[ "$d_choice" == "3" ]] && bash "$SCRIPT_DIR/scripts/add_ssl.sh"
            ;;
        4)
            echo -e "\n1) Add Database\n2) Delete Database\n3) Back"
            read -p "Option: " db_choice
            [[ "$db_choice" == "1" ]] && bash "$SCRIPT_DIR/scripts/add_db.sh"
            [[ "$db_choice" == "2" ]] && bash "$SCRIPT_DIR/scripts/del_db.sh"
            ;;
        5)
            echo -e "\n1) Add FTP User\n2) Delete FTP User\n3) Back"
            read -p "Option: " ftp_choice
            [[ "$ftp_choice" == "1" ]] && bash "$SCRIPT_DIR/scripts/add_ftp_user.sh"
            [[ "$ftp_choice" == "2" ]] && bash "$SCRIPT_DIR/scripts/del_ftp_user.sh"
            ;;
        6)
            echo -e "\n1) Enable Mail for Domain\n2) Disable Mail for Domain\n3) Add Mailbox\n4) Delete Mailbox\n5) Back"
            read -p "Option: " m_choice
            [[ "$m_choice" == "1" ]] && bash "$SCRIPT_DIR/scripts/add_mail_domain.sh"
            [[ "$m_choice" == "2" ]] && bash "$SCRIPT_DIR/scripts/del_mail_domain.sh"
            [[ "$m_choice" == "3" ]] && bash "$SCRIPT_DIR/scripts/add_mail_acc.sh"
            [[ "$m_choice" == "4" ]] && bash "$SCRIPT_DIR/scripts/del_mail_acc.sh"
            ;;
        0)
            echo "Goodbye!"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid option!${NC}"
            sleep 1
            ;;
    esac
done
