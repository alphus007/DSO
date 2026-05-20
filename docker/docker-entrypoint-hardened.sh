#!/bin/bash
# ============================================================
# Hardened entrypoint for the WordPress image.
#
# We let the upstream docker-entrypoint.sh do its normal work
# (write wp-config.php, install salts, etc), then layer our
# hardening on top before handing off to apache2-foreground.
#
# Why not in the Dockerfile? wp-config.php is generated at
# container start from env vars, so the file doesn't exist
# at build time.
# ============================================================
set -euo pipefail

WP_PATH="/var/www/html"
HARDENING_MARKER="${WP_PATH}/.hardening-applied"

apply_wp_config_hardening() {
    local cfg="${WP_PATH}/wp-config.php"
    [ -f "$cfg" ] || return 0
    grep -q "DISALLOW_FILE_EDIT" "$cfg" && return 0

    # Inject hardening constants before the "stop editing" marker.
    sed -i "/That's all, stop editing/i\\
define('DISALLOW_FILE_EDIT', true);\\
define('DISALLOW_FILE_MODS', false);\\
define('WP_DEBUG', false);\\
define('WP_DEBUG_LOG', false);\\
define('WP_DEBUG_DISPLAY', false);\\
define('WP_AUTO_UPDATE_CORE', true);\\
define('FORCE_SSL_ADMIN', false);\\
" "$cfg"
    echo "[hardening] wp-config.php constants injected"
}

apply_htaccess_hardening() {
    local ht="${WP_PATH}/.htaccess"
    grep -q "Hardening block" "$ht" 2>/dev/null && return 0

    cat >> "$ht" <<'HTACCESS'

# === Hardening block (injected by docker-entrypoint-hardened.sh) ===
Options -Indexes
<Files "xmlrpc.php">
    Require all denied
</Files>
<Files "wp-config.php">
    Require all denied
</Files>
<FilesMatch "^\.">
    Require all denied
</FilesMatch>

# Block ?author=N user enumeration
<IfModule mod_rewrite.c>
    RewriteEngine On
    RewriteCond %{QUERY_STRING} (^|&)author= [NC]
    RewriteRule .* - [F]
</IfModule>
HTACCESS
    echo "[hardening] .htaccess rules appended"
}

# Run the upstream entrypoint in a child shell, but only for setup work.
# We trap on success and apply hardening before the final exec.
if [ ! -f "$HARDENING_MARKER" ]; then
    # Let upstream do its config generation in the foreground (does not exec apache yet
    # if we override the cmd). Simplest reliable approach: source if possible, else just
    # rely on the fact that upstream runs setup on every start.
    /usr/local/bin/docker-entrypoint.sh true || true
    apply_wp_config_hardening
    apply_htaccess_hardening
    touch "$HARDENING_MARKER"
fi

# Hand off to the real entrypoint with the user's command (apache2-foreground)
exec /usr/local/bin/docker-entrypoint.sh "$@"
