#!/bin/bash
# docker-entrypoint-hardened.sh
# Extends the official WordPress entrypoint with security post-processing.
set -euo pipefail

# ── Run the official WordPress entrypoint logic ───────────────────────────────
# The official image ships the entrypoint at /usr/local/bin/docker-entrypoint.sh
source /usr/local/bin/docker-entrypoint.sh

# ── Inject hardening snippet into wp-config.php ──────────────────────────────
WP_CONFIG="/var/www/html/wp-config.php"
HARDENING_FILE="/usr/src/wordpress/wp-config-hardening.php"

if [ -f "$WP_CONFIG" ] && [ -f "$HARDENING_FILE" ]; then
    if ! grep -q "wp-config-hardening.php" "$WP_CONFIG"; then
        echo "" >> "$WP_CONFIG"
        echo "// Security hardening" >> "$WP_CONFIG"
        echo "require_once ABSPATH . 'wp-config-hardening.php';" >> "$WP_CONFIG"
        cp "$HARDENING_FILE" "/var/www/html/wp-config-hardening.php"
        chmod 440 "/var/www/html/wp-config-hardening.php"
        echo "[entrypoint] Security hardening config injected."
    fi
fi

# ── Lock down wp-config.php permissions ──────────────────────────────────────
if [ -f "$WP_CONFIG" ]; then
    chmod 440 "$WP_CONFIG"
    echo "[entrypoint] wp-config.php permissions set to 440."
fi

# ── Remove readme/license files that expose WP version ───────────────────────
for f in readme.html license.txt wp-config-sample.php; do
    if [ -f "/var/www/html/$f" ]; then
        rm -f "/var/www/html/$f"
        echo "[entrypoint] Removed $f"
    fi
done

echo "[entrypoint] Hardening complete. Starting Apache..."
exec "$@"
