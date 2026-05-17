#!/usr/bin/env bash
rm -rf "$(cd "$(dirname "$0")/.." && pwd)/dist"
echo "✔ dist/ cleaned."