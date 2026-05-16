<?php
/**
 * WordPress Security Hardening Configuration
 * Included from wp-config.php via require_once
 *
 * DevSecOps Lab – Hardened WordPress Deployment
 */

// ── Disable file editing from WordPress admin ─────────────────────────────────
define( 'DISALLOW_FILE_EDIT', true );

// ── Disable file/plugin modifications from admin ──────────────────────────────
define( 'DISALLOW_FILE_MODS', true );

// ── Force HTTPS for admin and logins ─────────────────────────────────────────
define( 'FORCE_SSL_ADMIN', true );

// ── Limit post revisions stored in DB ────────────────────────────────────────
define( 'WP_POST_REVISIONS', 3 );

// ── Disable XML-RPC (common attack vector) ────────────────────────────────────
add_filter( 'xmlrpc_enabled', '__return_false' );

// ── Block user enumeration via REST API ───────────────────────────────────────
add_filter( 'rest_endpoints', function( $endpoints ) {
    if ( ! is_user_logged_in() ) {
        if ( isset( $endpoints['/wp/v2/users'] ) ) {
            unset( $endpoints['/wp/v2/users'] );
        }
        if ( isset( $endpoints['/wp/v2/users/(?P<id>[\d]+)'] ) ) {
            unset( $endpoints['/wp/v2/users/(?P<id>[\d]+)'] );
        }
    }
    return $endpoints;
} );

// ── Hide WordPress version from meta tags ─────────────────────────────────────
remove_action( 'wp_head', 'wp_generator' );

// ── Disable directory browsing ────────────────────────────────────────────────
if ( ! defined( 'ABSPATH' ) ) {
    exit;
}

// ── Set secure cookie flags ───────────────────────────────────────────────────
@ini_set( 'session.cookie_httponly', true );
@ini_set( 'session.cookie_secure',   true );
@ini_set( 'session.use_only_cookies', true );

// ── Autoupdate settings ───────────────────────────────────────────────────────
define( 'WP_AUTO_UPDATE_CORE', 'minor' );  // auto-apply security patches

// ── Limit login attempts (basic – pair with a real plugin in prod) ────────────
define( 'WP_LOGIN_LOCKOUT_ENABLED', true );

// ── Disable debugging in production ──────────────────────────────────────────
define( 'WP_DEBUG',         false );
define( 'WP_DEBUG_LOG',     false );
define( 'WP_DEBUG_DISPLAY', false );
