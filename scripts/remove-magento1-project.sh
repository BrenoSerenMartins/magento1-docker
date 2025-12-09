#!/bin/bash

# =============================================
# Magento 1 Project Remover for Docker Workspace
# =============================================
# Usage: ./remove-project.sh <project-name>
#
# This script removes a Magento 1 project directory, Nginx configuration,
# database, and the entry from the hosts file.
# =============================================

set -e

# --- Colors and Styles ---
CYAN='\033[1;36m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
BOLD='\033[1m'
RESET='\033[0m'

# --- Relative Paths ---
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_ROOT="$( dirname "$SCRIPT_DIR" )"

# Load environment variables from .env file
if [ -f "${PROJECT_ROOT}/.env" ]; then
  source "${PROJECT_ROOT}/.env"
fi

# --- Input Validation ---
if [ -z "$1" ]; then
  echo -e "${RED}${BOLD}Error:${RESET} Project name is required."
  echo -e "${YELLOW}Usage:${RESET} $0 <project-name>"
  exit 1
fi

PROJECT_NAME="$1"

# --- Paths ---
WWW_PATH="${PROJECT_ROOT}/www/${PROJECT_NAME}"
NGINX_CONF_PATH="${PROJECT_ROOT}/nginx/conf.d/${PROJECT_NAME}.conf"

echo -e "${CYAN}============================================="
echo -e "${BOLD}Magento 1 Project Remover${RESET}"
echo -e "=============================================${RESET}"

# --- Confirmation ---
echo -e "${YELLOW}Are you sure you want to permanently delete the project '${PROJECT_NAME}'?${RESET}"
echo -e "This will remove the following:"
echo -e "  - Directory: ${WWW_PATH}"
echo -e "  - Nginx Conf: ${NGINX_CONF_PATH}"
echo -e "  - Database: magento1_$(echo "$PROJECT_NAME" | sed 's/[.-]/_/g')"
echo -e "  - Hosts entry: ${PROJECT_NAME}"
read -p "Type 'yes' to confirm: " CONFIRMATION

if [ "$CONFIRMATION" != "yes" ]; then
  echo -e "${RED}Aborted.${RESET}"
  exit 1
fi

# --- Remove project directory ---
if [ -d "$WWW_PATH" ]; then
  echo -e "${YELLOW}Removing project directory: ${WWW_PATH}...${RESET}"
  sudo rm -rf "$WWW_PATH"
  echo -e "${GREEN}✔ Project directory removed!${RESET}"
else
  echo -e "${YELLOW}Project directory not found.${RESET}"
fi

# --- Remove Nginx configuration ---
if [ -f "$NGINX_CONF_PATH" ]; then
  echo -e "${YELLOW}Removing Nginx configuration: ${NGINX_CONF_PATH}...${RESET}"
  sudo rm -f "$NGINX_CONF_PATH"
  echo -e "${GREEN}✔ Nginx configuration removed!${RESET}"
else
  echo -e "${YELLOW}Nginx configuration not found.${RESET}"
fi

# --- Remove SSL certificates ---
SSL_CERT_PATH="${PROJECT_ROOT}/nginx/ssl/${PROJECT_NAME}.pem"
SSL_KEY_PATH="${PROJECT_ROOT}/nginx/ssl/${PROJECT_NAME}-key.pem"

if [ -f "$SSL_CERT_PATH" ]; then
  echo -e "${YELLOW}Removing SSL certificate: ${SSL_CERT_PATH}...${RESET}"
  sudo rm -f "$SSL_CERT_PATH"
  echo -e "${GREEN}✔ SSL certificate removed!${RESET}"
else
  echo -e "${YELLOW}SSL certificate not found.${RESET}"
fi

if [ -f "$SSL_KEY_PATH" ]; then
  echo -e "${YELLOW}Removing SSL key: ${SSL_KEY_PATH}...${RESET}"
  sudo rm -f "$SSL_KEY_PATH"
  echo -e "${GREEN}✔ SSL key removed!${RESET}"
else
  echo -e "${YELLOW}SSL key not found.${RESET}"
fi

# --- Remove database ---
DB_DATABASE="magento1_$(echo "$PROJECT_NAME" | sed 's/[.-]/_/g')"
MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD}"
export MYSQL_PWD="${MYSQL_ROOT_PASSWORD}"

# Create a temporary file with the MySQL password
MYSQL_CNF_FILE=$(mktemp)
cat > "${MYSQL_CNF_FILE}" <<EOL
[client]
user=${MYSQL_ROOT_USER}
password=${MYSQL_ROOT_PASSWORD}
EOL

# Copy the temporary file to the container
docker compose -f "${PROJECT_ROOT}/docker-compose.yml" cp "${MYSQL_CNF_FILE}" mysql:/tmp/mysql.cnf

echo -e "${YELLOW}Dropping MySQL database: ${DB_DATABASE}...${RESET}"
docker compose -f "${PROJECT_ROOT}/docker-compose.yml" exec -T mysql mysql --defaults-extra-file=/tmp/mysql.cnf -e "DROP DATABASE IF EXISTS ${DB_DATABASE};"
if [ $? -eq 0 ]; then
  echo -e "${GREEN}✔ Database ${DB_DATABASE} dropped!${RESET}"
else
  echo -e "${RED}✖ Failed to drop database ${DB_DATABASE}.${RESET}"
fi

# Remove the temporary file from the container and the host
docker compose -f "${PROJECT_ROOT}/docker-compose.yml" exec -T mysql rm -f /tmp/mysql.cnf
rm -f "${MYSQL_CNF_FILE}"

# --- Remove hosts entry ---
HOSTS_LINE="127.0.0.1   ${PROJECT_NAME}"

# Check if running in WSL
if grep -q "Microsoft" /proc/version &>/dev/null; then
  echo -e "${YELLOW}WSL detected. Attempting to remove entry from Windows hosts file...${RESET}"
  WINDOWS_HOSTS_FILE="/mnt/c/Windows/System32/drivers/etc/hosts"
  
  if grep -q "${PROJECT_NAME}" "${WINDOWS_HOSTS_FILE}"; then
    echo -e "${YELLOW}Please manually remove the entry '${HOSTS_LINE}' from your Windows hosts file (${WINDOWS_HOSTS_FILE}).${RESET}"
  else
    echo -e "${YELLOW}Entry not found in Windows hosts file.${RESET}"
  fi
else
  # Standard Linux/macOS hosts file modification
  if grep -q "${PROJECT_NAME}" /etc/hosts; then
    echo -e "${YELLOW}Removing entry from /etc/hosts...${RESET}"
    if [ "$(id -u)" -ne 0 ]; then
      echo -e "${RED}Root permission required to edit /etc/hosts. Sudo will be requested...${RESET}"
      sudo sed -i "/${PROJECT_NAME}/d" /etc/hosts
    else
      sed -i "/${PROJECT_NAME}/d" /etc/hosts
    fi
    echo -e "${GREEN}✔ Entry removed from /etc/hosts!${RESET}"
  else
    echo -e "${YELLOW}Entry not found in /etc/hosts.${RESET}"
  fi
fi

# --- Restart Nginx ---
echo -e "${YELLOW}Restarting Nginx...${RESET}"
docker compose -f "${PROJECT_ROOT}/docker-compose.yml" restart nginx
echo -e "${GREEN}✔ Nginx restarted!${RESET}"

echo -e "\n${GREEN}Project '${PROJECT_NAME}' has been successfully removed.${RESET}"
