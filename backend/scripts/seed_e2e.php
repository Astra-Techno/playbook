<?php
/**
 * Reset and seed an isolated test/staging database.
 *
 * This command deliberately refuses production and requires a matching reset
 * key. It is safe for CI and a dedicated staging database, never for live
 * customer data.
 *
 * Usage:
 *   E2E_RESET_KEY=local-ci php backend/scripts/seed_e2e.php --key=local-ci
 */

require_once __DIR__ . '/../config/env.php';
require_once __DIR__ . '/../config/database.php';

$environment = getenv('APP_ENV') ?: '';
$configuredKey = getenv('E2E_RESET_KEY') ?: '';
$providedKey = '';
foreach ($argv as $argument) {
    if (str_starts_with($argument, '--key=')) {
        $providedKey = substr($argument, 6);
        break;
    }
}

if (!in_array($environment, ['test', 'staging'], true)) {
    fwrite(STDERR, "Refusing reset: APP_ENV must be test or staging.\n");
    exit(2);
}
if ($configuredKey === '' || $providedKey === '' || !hash_equals($configuredKey, $providedKey)) {
    fwrite(STDERR, "Refusing reset: a valid --key is required.\n");
    exit(2);
}

$db = Database::getConnection();
$preserve = ['migrations', 'schema_version'];
$tables = $db->query('SHOW TABLES')->fetchAll(PDO::FETCH_COLUMN);

$db->exec('SET FOREIGN_KEY_CHECKS = 0');
try {
    foreach ($tables as $table) {
        if (in_array($table, $preserve, true)) continue;
        $safeTable = str_replace('`', '``', $table);
        $db->exec("TRUNCATE TABLE `$safeTable`");
    }
} finally {
    $db->exec('SET FOREIGN_KEY_CHECKS = 1');
}

require __DIR__ . '/../seed.php';
