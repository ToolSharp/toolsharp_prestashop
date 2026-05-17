#!/usr/bin/env bash
# =============================================================================
# ToolSharp PrestaShop — watch.sh
#
# Watches a module's source directory for changes and automatically deploys
# to a target environment. Ideal for active development against a remote
# Docker container.
#
# Requires fswatch:  brew install fswatch
#
# Usage:
#   ./scripts/watch.sh --env dev_docker --module toolsharp_productdiscounts
#
# Press Ctrl+C to stop watching.
# =============================================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MODULES_DIR="$REPO_ROOT/modules"

# ---- Parse arguments --------------------------------------------------------
ENV_NAME=""
TARGET_MODULE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --env|-e)    ENV_NAME="$2";      shift 2 ;;
        --module|-m) TARGET_MODULE="$2"; shift 2 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

[[ -n "$ENV_NAME" ]]      || { echo "✖ --env is required"    >&2; exit 1; }
[[ -n "$TARGET_MODULE" ]] || { echo "✖ --module is required" >&2; exit 1; }

WATCH_DIR="$MODULES_DIR/$TARGET_MODULE"
[[ -d "$WATCH_DIR" ]] || { echo "✖ Module not found: $WATCH_DIR" >&2; exit 1; }

# ---- Check fswatch is available ---------------------------------------------
if ! command -v fswatch &>/dev/null; then
    echo "✖ fswatch not found. Install it with:"
    echo "    brew install fswatch"
    exit 1
fi

# ---- Debounce ---------------------------------------------------------------
# Avoid firing the deploy multiple times for a burst of rapid file writes.
LAST_DEPLOY=0
DEBOUNCE_SECONDS=1

deploy() {
    local now
    now=$(date +%s)
    local since=$(( now - LAST_DEPLOY ))
    if (( since < DEBOUNCE_SECONDS )); then
        return
    fi
    LAST_DEPLOY=$now

    echo ""
    echo "── $(date '+%H:%M:%S')  Change detected — deploying $TARGET_MODULE → $ENV_NAME"
    if "$REPO_ROOT/scripts/deploy.sh" \
            --env "$ENV_NAME" \
            --module "$TARGET_MODULE"; then
        echo "── ✔ Ready"
    else
        echo "── ✖ Deploy failed (see above)"
    fi
}

# ---- Watch ------------------------------------------------------------------
echo "▸ Watching $WATCH_DIR"
echo "  Environment : $ENV_NAME"
echo "  Module      : $TARGET_MODULE"
echo "  Press Ctrl+C to stop."
echo ""

# Export the function so the subshell spawned by fswatch can call it
export REPO_ROOT ENV_NAME TARGET_MODULE DEBOUNCE_SECONDS
export LAST_DEPLOY

fswatch \
    --recursive \
    --event Created \
    --event Updated \
    --event Removed \
    --event Renamed \
    --exclude '\.DS_Store$' \
    --exclude '\.swp$' \
    --exclude '\.git' \
    "$WATCH_DIR" | while read -r _event; do
        deploy
    done
