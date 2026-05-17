#!/usr/bin/env bash
# =============================================================================
# ToolSharp PrestaShop — build.sh
#
# Packages one or all modules into a clean zip ready for PrestaShop.
# The version is read from <module>/version.txt unless --version is passed.
#
# Usage:
#   ./scripts/build.sh                          # build all modules
#   ./scripts/build.sh toolsharp_productdiscounts
#   ./scripts/build.sh --version 1.2.0 toolsharp_productdiscounts
#
# Output: dist/<module_name>-<version>.zip
# =============================================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MODULES_DIR="$REPO_ROOT/modules"
DIST_DIR="$REPO_ROOT/dist"

# VERSION may be overridden by --version; otherwise each module reads its own.
FORCED_VERSION=""

# ---- Parse arguments --------------------------------------------------------
TARGET_MODULE=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --version|-v)
            FORCED_VERSION="$2"
            shift 2
            ;;
        -*)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
        *)
            TARGET_MODULE="$1"
            shift
            ;;
    esac
done

# ---- Helpers ----------------------------------------------------------------
log()  { echo "▸ $*"; }
ok()   { echo "✔ $*"; }
warn() { echo "⚠ $*"; }
err()  { echo "✖ $*" >&2; exit 1; }

ensure_index_php() {
    local dir="$1"
    find "$dir" -type d | while read -r d; do
        if [[ ! -f "$d/index.php" ]]; then
            cat > "$d/index.php" <<'INDEX'
<?php
header('Expires: Mon, 26 Jul 1997 05:00:00 GMT');
header('Last-Modified: '.gmdate('D, d M Y H:i:s').' GMT');
header('Cache-Control: no-store, no-cache, must-revalidate');
header('Cache-Control: post-check=0, pre-check=0', false);
header('Pragma: no-cache');
header('Location: ../');
exit;
INDEX
        fi
    done
}

build_module() {
    local module_name="$1"
    local src_dir="$MODULES_DIR/$module_name"

    [[ -d "$src_dir" ]] || err "Module directory not found: $src_dir"

    # ---- Resolve version ----------------------------------------------------
    local version="$FORCED_VERSION"
    if [[ -z "$version" ]]; then
        local ver_file="$src_dir/version.txt"
        if [[ -f "$ver_file" ]]; then
            version="$(tr -d '[:space:]' < "$ver_file")"
        fi
    fi

    if [[ -z "$version" ]]; then
        err "No version found for $module_name. Add a version.txt or pass --version."
    fi

    local zip_name="${module_name}-${version}"
    local zip_path="$DIST_DIR/${zip_name}.zip"

    log "Building $module_name @ $version ..."

    local tmp_dir
    tmp_dir="$(mktemp -d)"
    trap "rm -rf '$tmp_dir'" EXIT

    rsync -a \
        --exclude='.git' \
        --exclude='.gitignore' \
        --exclude='.DS_Store' \
        --exclude='*.swp' \
        --exclude='node_modules' \
        "$src_dir/" "$tmp_dir/$module_name/"

    ensure_index_php "$tmp_dir/$module_name"

    mkdir -p "$DIST_DIR"

    (cd "$tmp_dir" && zip -r "$zip_path" "$module_name" -x "*.DS_Store")

    ok "Built: $zip_path"
}

# ---- Main -------------------------------------------------------------------
if [[ -n "$TARGET_MODULE" ]]; then
    build_module "$TARGET_MODULE"
else
    log "Building all modules in $MODULES_DIR"
    found=0
    for dir in "$MODULES_DIR"/*/; do
        [[ -d "$dir" ]] || continue
        build_module "$(basename "$dir")"
        ((found++))
    done
    [[ $found -gt 0 ]] || warn "No modules found in $MODULES_DIR"
    ok "Done — $found module(s) built."
fi