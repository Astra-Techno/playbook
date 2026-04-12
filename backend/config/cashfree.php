<?php

require_once __DIR__ . '/env.php';

/**
 * Cashfree credentials — loaded from backend/.env
 * Set your keys in .env (copy .env.example → .env)
 */

define('CASHFREE_APP_ID',     getenv('CASHFREE_APP_ID')     ?: 'your_cashfree_app_id');
define('CASHFREE_SECRET_KEY', getenv('CASHFREE_SECRET_KEY') ?: 'your_cashfree_secret_key');
define('CASHFREE_ENV',        getenv('CASHFREE_ENV')        ?: 'sandbox');

define('CASHFREE_BASE_URL',
    CASHFREE_ENV === 'production'
        ? 'https://api.cashfree.com/pg'
        : 'https://sandbox.cashfree.com/pg'
);

define('CASHFREE_API_VERSION', '2023-08-01');
