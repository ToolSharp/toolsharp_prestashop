#!/usr/bin/env bash
# =============================================================================
# ToolSharp PrestaShop — deploy.sh
#
# Deploys a built module to a target environment.
# Reads connection details from config/environments.sh.
#
# Usage:
#   ./scripts/deploy.sh --env dev_docker --module toolsharp_productdiscounts
#   ./scripts/deploy.sh --env staging    --module toolsharp_productdiscounts
#   ./scripts/deploy.sh --env production --module toolsharp_productdiscounts
#
# If --module is omitted, all modules are deployed.
# Add --build to rebuild the zip before deploying.
# =============================================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MODULES_DIR="$REPO_ROOT/modules"
DIST_DIR="$REPO_ROOT/dist"
CONFIG_FILE="$REPO_ROOT/config/environments.sh"

# ---- Parse arguments --------------------------------------------------------
ENV_NAME=""
TARGET_MODULE=""
DO_BUILD=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --env|-e)        ENV_NAME="$2";       shift 2 ;;
        --module|-m)     TARGET_MODULE="$2";  shift 2 ;;
        --build|-b)      DO_BUILD=true;       shift   ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

# ---- Helpers ----------------------------------------------------------------
log()  { echo "▸ $*"; }
ok()   { echo "✔ $*"; }
err()  { echo "✖ $*" >&2; exit 1; }

[[ -n "$ENV_NAME" ]] || err "No environment specified. Use --env <name>"
[[ -f "$CONFIG_FILE" ]] || err "Config not found: $CONFIG_FILE\n  Copy config/environments.example.sh → config/environments.sh and fill in your values."

# shellcheck source=/dev/null
source "$CONFIG_FILE"

# ---- Load env config --------------------------------------------------------
# Variable names are prefixed with the uppercased env name, e.g. DEV_DOCKER_HOST
prefix="$(echo "$ENV_NAME" | tr '[:lower:]' '[:upper:]')"

get_var() { eval echo "\${${prefix}_${1}:-}"; }

METHOD="$(get_var METHOD)"
HOST="$(get_var HOST)"
PORT="$(get_var PORT)"
USER_VAR="$(get_var USER)"
SSH_KEY="$(get_var SSH_KEY)"
PASS="$(get_var PASS)"
MODULES_PATH="$(get_var MODULES_PATH)"
POST_CMD="$(get_var POST_DEPLOY_CMD)"

[[ -n "$METHOD" ]] || err "No METHOD configured for environment '$ENV_NAME'."

# ---- Optionally build first -------------------------------------------------
if $DO_BUILD; then
    log "Building before deploy..."
    if [[ -n "$TARGET_MODULE" ]]; then
        "$REPO_ROOT/scripts/build.sh" "$TARGET_MODULE"
    else
        "$REPO_ROOT/scripts/build.sh"
    fi
fi

# ---- Collect modules to deploy ----------------------------------------------
modules=()
if [[ -n "$TARGET_MODULE" ]]; then
    [[ -d "$MODULES_DIR/$TARGET_MODULE" ]] || err "Module not found: $TARGET_MODULE"
    modules=("$TARGET_MODULE")
else
    for dir in "$MODULES_DIR"/*/; do
        [[ -d "$dir" ]] && modules+=("$(basename "$dir")")
    done
fi

[[ ${#modules[@]} -gt 0 ]] || err "No modules found to deploy."

# ---- Deploy per method ------------------------------------------------------
deploy_rsync() {
    local module="$1"
    local src="$MODULES_DIR/$module/"
    local dst="${USER_VAR}@${HOST}:${MODULES_PATH}/${module}/"

    log "[$ENV_NAME] rsync → $dst"

    local ssh_opts="-p ${PORT:-22} -o StrictHostKeyChecking=accept-new"
    [[ -n "$SSH_KEY" ]] && ssh_opts="$ssh_opts -i $SSH_KEY"

    rsync -az --delete \
        -e "ssh $ssh_opts" \
        --exclude='.git' \
        --exclude='.DS_Store' \
        "$src" "$dst"

    ok "Synced $module"
}

deploy_ftp() {
    local module="$1"
    local src_dir="$MODULES_DIR/$module"
    local remote_base="${MODULES_PATH}/${module}"

    log "[$ENV_NAME] FTP upload of $module → $remote_base"

    # curl FTP: upload every file preserving relative paths
    find "$src_dir" -type f \
        ! -name '.DS_Store' \
        ! -name '*.swp' | while read -r file; do

        local rel="${file#$src_dir/}"
        local remote_path="$remote_base/$rel"
        local remote_dir
        remote_dir="$(dirname "$remote_path")"

        # Ensure remote directory exists
        curl -s --ftp-create-dirs \
            --user "${USER_VAR}:${PASS}" \
            "ftp://${HOST}:${PORT:-21}/${remote_dir}/" \
            -Q "-MKD ${remote_dir}" 2>/dev/null || true

        curl -s -T "$file" \
            --user "${USER_VAR}:${PASS}" \
            "ftp://${HOST}:${PORT:-21}/${remote_path}"
    done

    ok "Uploaded $module via FTP"
}

deploy_zip() {
    local module="$1"
    # Just make sure there's a zip in dist/ — build if missing
    local zip_path="$DIST_DIR/${module}.zip"
    if [[ ! -f "$zip_path" ]]; then
        log "No zip found for $module, building..."
        "$REPO_ROOT/scripts/build.sh" "$module"
    fi
    ok "ZIP ready for manual upload: $zip_path"
}

run_post_cmd() {
    [[ -z "$POST_CMD" ]] && return
    log "Running post-deploy command on $HOST..."
    local ssh_opts="-p ${PORT:-22} -o StrictHostKeyChecking=accept-new"
    [[ -n "$SSH_KEY" ]] && ssh_opts="$ssh_opts -i $SSH_KEY"
    # shellcheck disable=SC2029
    ssh $ssh_opts "${USER_VAR}@${HOST}" "$POST_CMD"
    ok "Post-deploy command complete."
}

# ---- Execute ----------------------------------------------------------------
for module in "${modules[@]}"; do
    case "$METHOD" in
        rsync) deploy_rsync "$module" ;;
        ftp)   deploy_ftp   "$module" ;;
        zip)   deploy_zip   "$module" ;;
        *)     err "Unknown method '$METHOD' for environment '$ENV_NAME'" ;;
    esac
done

[[ "$METHOD" != "zip" ]] && run_post_cmd

ok "Deploy to '$ENV_NAME' complete."
