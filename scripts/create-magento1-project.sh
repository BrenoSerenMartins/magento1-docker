#!/bin/bash

# =============================================
# Magento 1 Project Creator for Docker Workspace
# =============================================
# Usage: ./scripts/create-magento1-project.sh <project-name>
#
# This script creates a new Magento 1 project directory and automatically
# generates the Nginx configuration file for access via <project-name>
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

# Validate project name (lowercase letters, numbers, hyphens, and dots)
if ! [[ "$PROJECT_NAME" =~ ^[a-z0-9.-]+$ ]]; then
    echo -e "${RED}${BOLD}Error:${RESET} Invalid project name."
    echo -e "${YELLOW}Use only lowercase letters, numbers, hyphens, and dots (e.g., my-project.local).${RESET}"
    exit 1
fi

# --- Paths ---
WWW_PATH="${PROJECT_ROOT}/www/${PROJECT_NAME}"
CONTAINER_WWW_PATH="/var/www/${PROJECT_NAME}"
NGINX_CONF_PATH="${PROJECT_ROOT}/nginx/conf.d/${PROJECT_NAME}.conf"

# --- Check for existing project ---
if [ -d "$WWW_PATH" ] || [ -f "$NGINX_CONF_PATH" ]; then
    echo -e "${RED}${BOLD}Error:${RESET} A project with the name '${PROJECT_NAME}' already exists."
    exit 1
fi

echo -e "${CYAN}============================================="
echo -e "${BOLD}Magento 1 Project Creator${RESET}"
echo -e "=============================================${RESET}"

# === Create project directory ===
echo -e "${YELLOW}Creating project directory: ${WWW_PATH}...${RESET}"
mkdir -p "$WWW_PATH"
echo -e "${GREEN}✔ Project directory created!${RESET}"


# === Automatic creation of the unique database for the project ===
DB_DATABASE="magento1_$(echo "$PROJECT_NAME" | sed 's/[.-]/_/g')" # Replaces hyphens and dots with underscores for the DB
DB_USERNAME="magento1"
DB_PASSWORD="magento1"
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

echo -e "${YELLOW}Creating MySQL database: ${DB_DATABASE}...${RESET}"
# Waits for MySQL to be ready before creating the database
for i in $(seq 1 30);
  do
  if docker compose -f "${PROJECT_ROOT}/docker-compose.yml" exec -T mysql mysql --defaults-extra-file=/tmp/mysql.cnf -e "SELECT 1;" 2>/dev/null;
  then
    break
  else
    sleep 2
  fi
done

# Creates the database if it doesn't exist using root
docker compose -f "${PROJECT_ROOT}/docker-compose.yml" exec -T mysql mysql --defaults-extra-file=/tmp/mysql.cnf -e "CREATE DATABASE IF NOT EXISTS ${DB_DATABASE};"
if [ $? -eq 0 ]; then
  echo -e "${GREEN}✔ Database ${DB_DATABASE} ready!${RESET}"
else
  echo -e "${RED}✖ Failed to create database ${DB_DATABASE}.${RESET}"
docker compose -f "${PROJECT_ROOT}/docker-compose.yml" exec -T mysql rm -f /tmp/mysql.cnf
  rm -f "${MYSQL_CNF_FILE}"
  exit 1
fi

# Ensures that the magento1@'%' and magento1@'localhost' users exist, correct password, correct plugin and grants permissions
docker compose -f "${PROJECT_ROOT}/docker-compose.yml" exec -T mysql mysql --defaults-extra-file=/tmp/mysql.cnf -e "CREATE USER IF NOT EXISTS '${DB_USERNAME}'@'%' IDENTIFIED WITH mysql_native_password BY '${DB_PASSWORD}';"
docker compose -f "${PROJECT_ROOT}/docker-compose.yml" exec -T mysql mysql --defaults-extra-file=/tmp/mysql.cnf -e "GRANT ALL PRIVILEGES ON ${DB_DATABASE}.* TO '${DB_USERNAME}'@'%';"
docker compose -f "${PROJECT_ROOT}/docker-compose.yml" exec -T mysql mysql --defaults-extra-file=/tmp/mysql.cnf -e "FLUSH PRIVILEGES;"

# Remove the temporary file from the container and the host
docker compose -f "${PROJECT_ROOT}/docker-compose.yml" exec -T mysql rm -f /tmp/mysql.cnf
rm -f "${MYSQL_CNF_FILE}"


echo -e "${YELLOW}Generating Nginx configuration at:${RESET} $NGINX_CONF_PATH"
cp "${PROJECT_ROOT}/nginx/conf.d/magento1.conf.example" "$NGINX_CONF_PATH"
sed -i "s/{{PROJECT_NAME}}/${PROJECT_NAME}/g" "$NGINX_CONF_PATH"
sed -i "s|{{CONTAINER_WWW_PATH}}|${CONTAINER_WWW_PATH}|g" "$NGINX_CONF_PATH"

echo -e "${GREEN}✔ Nginx configuration created!${RESET}"

echo -e "\n${CYAN}============================================="
echo -e "${BOLD}Project structure ready!${RESET}"
echo -e "=============================================${RESET}"
echo -e "${BOLD}Directory:${RESET} $WWW_PATH"
echo -e "${BOLD}Nginx conf:${RESET} $NGINX_CONF_PATH"
echo -e "${BOLD}Database:${RESET} ${DB_DATABASE}"
echo -e "${BOLD}DB User:${RESET} ${DB_USERNAME}"
echo -e "${BOLD}DB Pass:${RESET} ${DB_PASSWORD}"


# Adds the entry to /etc/hosts if it doesn't exist
HOSTS_LINE="127.0.0.1   ${PROJECT_NAME}"

# Check if running in WSL
if grep -q "Microsoft" /proc/version &>/dev/null;
then
  echo -e "${YELLOW}WSL detected. Attempting to modify Windows hosts file...${RESET}"
  WINDOWS_HOSTS_FILE="/mnt/c/Windows/System32/drivers/etc/hosts"
  
  if grep -q "${PROJECT_NAME}" "${WINDOWS_HOSTS_FILE}"; then
    echo -e "${YELLOW}Entry already exists in Windows hosts file:${RESET} ${PROJECT_NAME}"
  else
    echo -e "${YELLOW}Adding entry to Windows hosts file...${RESET}"
    powershell.exe -Command "Start-Process powershell -Verb RunAs -ArgumentList '-Command \"Add-Content -Path C:\\Windows\\System32\\drivers\\etc\\hosts -Value \\\"${HOSTS_LINE}\\\"\"'"
    echo -e "${GREEN}✔ Entry added to Windows hosts file! You may need to approve the UAC prompt.${RESET}"
  fi
else
  # Standard Linux/macOS hosts file modification
  if grep -q "${PROJECT_NAME}" /etc/hosts;
  then
    echo -e "${YELLOW}Entry already exists in /etc/hosts:${RESET} ${PROJECT_NAME}"
  else
    echo -e "${YELLOW}Adding entry to /etc/hosts...${RESET}"
    if [ "$(id -u)" -ne 0 ]; then
      echo -e "${RED}Root permission required to edit /etc/hosts. Sudo will be requested...${RESET}"
      echo "$HOSTS_LINE" | sudo tee -a /etc/hosts > /dev/null
    else
      echo "$HOSTS_LINE" >> /etc/hosts
    fi
    echo -e "${GREEN}✔ Entry added to /etc/hosts!${RESET}"
  fi
fi


# Restarts the webserver to apply new configuration
echo -e "${YELLOW}Restarting the webserver (nginx)...${RESET}"
docker compose -f "${PROJECT_ROOT}/docker-compose.yml" restart nginx
echo -e "${GREEN}✔ Webserver restarted!${RESET}"

echo -e "\n${CYAN}============================================="
echo -e "${BOLD}Automated Magento 1 Download${RESET}"
echo -e "=============================================${RESET}"
echo -e "${YELLOW}Cloning Magento 1.9.4.5 from OpenMage repository...${RESET}"
sudo rm -rf /tmp/magento-mirror
git clone --depth 1 --branch 1.9.4.5 https://github.com/OpenMage/magento-mirror.git /tmp/magento-mirror
echo -e "${GREEN}✔ Clone complete!${RESET}"

echo -e "${YELLOW}Copying Magento files to ${WWW_PATH}...${RESET}"
rsync -a --exclude='.git/' /tmp/magento-mirror/ "${WWW_PATH}/"
echo -e "${GREEN}✔ Copy complete!${RESET}"

echo -e "${YELLOW}Skipping Base URL validation...${RESET}"
CONFIG_PHP_FILE="${WWW_PATH}/app/code/core/Mage/Install/Model/Installer/Config.php"
sed -i "s/if (!\\\\$this->_getInstaller()->getDataModel()->getSkipBaseUrlValidation()) {/if (false) {/g" "$CONFIG_PHP_FILE"
sed -i "s/if (!empty(\\\\$data['use_secure']) && !\\\\$this->_getInstaller()->getDataModel()->getSkipUrlValidation()) {/if (false) {/g" "$CONFIG_PHP_FILE"
echo -e "${GREEN}✔ Base URL validation skipped!${RESET}"

echo -e "${YELLOW}Removing temporary files...${RESET}"
rm -rf /tmp/magento-mirror
echo -e "${GREEN}✔ Temporary files removed!${RESET}"

echo -e "\n${CYAN}============================================="
echo -e "${BOLD}Installation Ready!${RESET}"
echo -e "=============================================${RESET}"
echo -e "${YELLOW}Access the site to begin the installation process:${RESET}"
echo -e "   http://${PROJECT_NAME}"

echo -e "\n${GREEN}All set! Open the URL above in your browser to complete the installation.${RESET}"

echo -e "${YELLOW}Setting file permissions...${RESET}"
docker compose -f "${PROJECT_ROOT}/docker-compose.yml" exec php-fpm chown -R www-data:www-data "${CONTAINER_WWW_PATH}"
docker compose -f "${PROJECT_ROOT}/docker-compose.yml" exec php-fpm find "${CONTAINER_WWW_PATH}" -type d -exec chmod 775 {} \;
docker compose -f "${PROJECT_ROOT}/docker-compose.yml" exec php-fpm find "${CONTAINER_WWW_PATH}" -type f -exec chmod 664 {} \;
echo -e "${GREEN}✔ File permissions set!${RESET}"