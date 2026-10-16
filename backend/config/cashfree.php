<?php

require_once __DIR__ . '/env.php';
require_once __DIR__ . '/database.php';

/**
 * Cashfree credentials — loaded from DB config table, falling back to .env
 */

// Helper: read from config table, fallback to env, then default
function _cfConfig(string $key, string $envKey, string $default): string {
    static $cache = [];
    if (isset($cache[$key])) return $cache[$key];

    try {
        $db = Database::getConnection();
        $stmt = $db->prepare("SELECT `value` FROM config WHERE `key` = ? LIMIT 1");
        $stmt->execute([$key]);
        $val = $stmt->fetchColumn();
        if ($val !== false && $val !== null && $val !== '') {
            $cache[$key] = $val;
            return $val;
        }
    } catch (Exception $e) {}

    $env = getenv($envKey);
    $cache[$key] = ($env !== false && $env !== '') ? $env : $default;
    return $cache[$key];
}

define('CASHFREE_APP_ID',     _cfConfig('cashfree_app_id',     'CASHFREE_APP_ID',     'your_cashfree_app_id'));
define('CASHFREE_SECRET_KEY', _cfConfig('cashfree_secret_key', 'CASHFREE_SECRET_KEY', 'your_cashfree_secret_key'));
define('CASHFREE_ENV',        _cfConfig('cashfree_env',        'CASHFREE_ENV',        'sandbox'));

define('CASHFREE_BASE_URL',
    CASHFREE_ENV === 'production'
        ? 'https://api.cashfree.com/pg'
        : 'https://sandbox.cashfree.com/pg'
);

define('CASHFREE_API_VERSION', '2023-08-01');
