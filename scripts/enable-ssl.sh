#!/bin/bash

# =============================================
# SSL Enabler for Magento 1 Projects
# =============================================
# Usage: ./scripts/enable-ssl.sh <project-name>
#
# This script configures an existing HTTP project to use HTTPS.
# =============================================

set -e

# --- Colors and Styles ---
CYAN='\033[1;36m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
BOLD='\033[1m'
RESET='\033[0m'

# --- Input Validation ---
if [ -z "$1" ]; then
  echo -e "${RED}${BOLD}Error:${RESET} Project name is required."
  echo -e "${YELLOW}Usage:${RESET} $0 <project-name>"
  exit 1
fi

PROJECT_NAME="$1"

# --- Relative Paths ---
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_ROOT="$( dirname "$SCRIPT_DIR" )"
CERTS_DIR="${PROJECT_ROOT}/nginx/certs"
NGINX_CONF_PATH="${PROJECT_ROOT}/nginx/conf.d/${PROJECT_NAME}.conf"

echo -e "${CYAN}============================================="
echo -e "${BOLD}Enabling SSL for: ${PROJECT_NAME}${RESET}"
echo -e "=============================================${RESET}"

# 1. Generate Certificates
echo -e "${YELLOW}Generating SSL certificate and key...${RESET}"
mkdir -p "$CERTS_DIR"
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout "${CERTS_DIR}/${PROJECT_NAME}.key" \
  -out "${CERTS_DIR}/${PROJECT_NAME}.crt" \
  -subj "/CN=${PROJECT_NAME}"
echo -e "${GREEN}✔ Certificates generated.${RESET}"

# 2. Fix Permissions
echo -e "${YELLOW}Fixing certificate permissions...${RESET}"
sudo chmod 644 "${CERTS_DIR}/${PROJECT_NAME}.key" "${CERTS_DIR}/${PROJECT_NAME}.crt"
echo -e "${GREEN}✔ Permissions fixed.${RESET}"

# 3. Create Nginx Configuration from Template
echo -e "${YELLOW}Creating Nginx configuration for HTTPS from template...${RESET}"
sudo cp "${PROJECT_ROOT}/nginx/conf.d/magento1.conf.ssl.example" "$NGINX_CONF_PATH"
sudo sed -i "s/{{PROJECT_NAME}}/${PROJECT_NAME}/g" "$NGINX_CONF_PATH"
echo -e "${GREEN}✔ Nginx configuration created.${RESET}"

# 4. Update Magento Database
DB_DATABASE="magento1_$(echo "$PROJECT_NAME" | sed 's/[.-]/_/g')"
echo -e "${YELLOW}Updating Magento database (${DB_DATABASE}) to use HTTPS...${RESET}"
docker compose exec mysql mysql -u magento1 -pmagento1 "$DB_DATABASE" -e "
UPDATE core_config_data SET value = 'https://""${PROJECT_NAME}""/' WHERE path = 'web/secure/base_url';
UPDATE core_config_data SET value = 'https://""${PROJECT_NAME}""/' WHERE path = 'web/unsecure/base_url';
UPDATE core_config_data SET value = 1 WHERE path = 'web/secure/use_in_frontend';
UPDATE core_config_data SET value = 1 WHERE path = 'web/secure/use_in_adminhtml';
"
echo -e "${GREEN}✔ Database updated.${RESET}"

# 5. Clear Magento Cache
echo -e "${YELLOW}Clearing Magento cache...${RESET}"
sudo rm -rf "${PROJECT_ROOT}/www/${PROJECT_NAME}/var/cache/"*
echo -e "${GREEN}✔ Cache cleared.${RESET}"

# 6. Restart Nginx
echo -e "${YELLOW}Restarting Nginx to apply all changes...${RESET}"
docker compose up -d --force-recreate nginx
echo -e "${GREEN}✔ Nginx restarted.${RESET}"

echo -e "\n${CYAN}============================================="
echo -e "${BOLD}SSL for ${PROJECT_NAME} is enabled!${RESET}"
echo -e "=============================================${RESET}"
echo -e "${YELLOW}ACTION REQUIRED:${RESET} You must now import the certificate into your OS."
echo -e "Certificate location: ${CERTS_DIR}/${PROJECT_NAME}.crt"
echo -e "\nAfter importing, access your site at: https://${PROJECT_NAME}"