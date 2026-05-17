#!/usr/bin/env bash
# =============================================================================
# ToolSharp PrestaShop — Environment Configuration Template
#
# Copy this file to environments.sh and fill in your values.
# environments.sh is gitignored and should NEVER be committed.
#
# Supported deployment methods per environment:
#   rsync  — SSH + rsync (recommended for Docker containers and VPS)
#   ftp    — FTP upload via curl
#   zip    — just build the zip (for manual Back Office upload)
# =============================================================================

# List every environment name you want available (space-separated).
# The name is used as a CLI argument: ./scripts/deploy.sh --env dev_docker
ENVIRONMENTS=(
    dev_docker
    staging
    production
)

# -----------------------------------------------------------------------------
# dev_docker — Remote Docker container over SSH
# -----------------------------------------------------------------------------
DEV_DOCKER_METHOD="rsync"
DEV_DOCKER_HOST="your-server.example.com"
DEV_DOCKER_PORT="22"
DEV_DOCKER_USER="root"
DEV_DOCKER_SSH_KEY="~/.ssh/id_rsa"          # leave empty to use ssh-agent
# Path to the PrestaShop modules directory INSIDE the container/server
DEV_DOCKER_MODULES_PATH="/var/www/html/modules"
# Optional: run these commands on the remote after sync (clear PS cache etc.)
# Leave empty to skip.
DEV_DOCKER_POST_DEPLOY_CMD="cd /var/www/html && php bin/console cache:clear --env=prod"

# -----------------------------------------------------------------------------
# staging — Another remote (FTP example)
# -----------------------------------------------------------------------------
STAGING_METHOD="ftp"
STAGING_HOST="ftp.staging.example.com"
STAGING_PORT="21"
STAGING_USER="ftpuser"
STAGING_PASS="yourpassword"
STAGING_MODULES_PATH="/public_html/modules"
STAGING_POST_DEPLOY_CMD=""

# -----------------------------------------------------------------------------
# production — ZIP only (manual upload via Back Office)
# -----------------------------------------------------------------------------
PRODUCTION_METHOD="zip"
PRODUCTION_HOST=""
PRODUCTION_PORT=""
PRODUCTION_USER=""
PRODUCTION_PASS=""
PRODUCTION_MODULES_PATH=""
PRODUCTION_POST_DEPLOY_CMD=""
