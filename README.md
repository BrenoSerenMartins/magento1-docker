# Magento 1 Development Environment with Docker

This project provides a complete and automated local development environment for **Magento 1** projects, utilizing Docker and Docker Compose.

## Overview

The goal of this environment is to simplify the setup of new Magento 1 instances, providing a fast and consistent workflow for developers. With a single command, you can create a new Magento 1 project, with the database and web server automatically configured.

## Included Services

This environment is composed of the following Docker services:

-   **Nginx:** Modern and high-performance web server.
-   **PHP-FPM:** PHP 5.6 with the necessary extensions for Magento 1.
-   **MySQL:** MySQL 5.7 database.
-   **Redis:** High-performance cache.
-   **phpMyAdmin:** Web interface for database management.

## Prerequisites

Before you begin, make sure you have the following software installed:

-   [Docker](https://docs.docker.com/get-docker/)
-   [Docker Compose](https://docs.docker.com/compose/install/)

## How to Use

### 1. Clone the Repository

```bash
git clone <repository-URL>
cd <project-directory>
```

### 2. Configure the Root Database Password

This environment needs a root password for the MySQL service. The creation script uses this password to automatically create databases and users for each new project.

Copy the `.env.example` file to `.env` and set the `MYSQL_ROOT_PASSWORD`.

```bash
cp .env.example .env
```

You only need to set the `MYSQL_ROOT_PASSWORD`. The project creation script will handle the creation of specific databases and users for each project automatically. The other variables in `.env.example` (`MYSQL_DATABASE`, `MYSQL_USER`, `MYSQL_PASSWORD`) are used by `docker-compose` for the initial setup of the default database, but the project creation script will create unique databases for each new Magento project.

### 3. Bring Up the Containers

To start all services in the background, run:

```bash
docker compose up -d
```

### 4. Create a New Magento 1 Project

Use the `create-magento1-project.sh` script to create a new project. The script will handle everything: creating the directory, the database, the Nginx configuration, and downloading Magento 1.

```bash
./scripts/create-magento1-project.sh your-project.local
```

The script will ask for your `sudo` password to add an entry to the `/etc/hosts` file, allowing you to access the project via the `http://your-project.local` domain.

After completion, access the URL in your browser to start the Magento installation process.

### 5. Removing a Project

To remove a project, use the `remove-magento1-project.sh` script. It will remove the project directory, the database, and the Nginx configuration.

```bash
./scripts/remove-magento1-project.sh your-project.local
```

## Directory Structure

-   `www/`: Contains the files for your Magento projects. Each project resides in its own subdirectory.
-   `nginx/conf.d/`: Stores the Nginx configuration files. A `.conf` file is generated for each project.
-   `php-fpm/`: Contains the `Dockerfile` and configurations for the custom PHP-FPM image.
-   `scripts/`: Automation scripts for creating and removing projects.

## Accessing Services

-   **Magento Projects:** `http://<project-name>`
-   **phpMyAdmin:** `http://localhost:8080`
-   **MySQL:** `localhost:3306`
-   **Redis:** `localhost:6379`