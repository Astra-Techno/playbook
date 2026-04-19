<?php
/**
 * KoCourt – Database Migration Runner
 *
 * Usage (from backend/ directory):
 *   php scripts/migrate.php            — run all pending migrations
 *   php scripts/migrate.php status     — show migration status
 *   php scripts/migrate.php rollback   — show applied (manual rollback reminder)
 */

require_once __DIR__ . '/../config/env.php';
require_once __DIR__ . '/../config/database.php';

$command = $argv[1] ?? 'migrate';
$db      = Database::getConnection();

// ── Ensure migrations tracking table exists ───────────────────────────────
$db->exec("
    CREATE TABLE IF NOT EXISTS migrations (
        id         INT AUTO_INCREMENT PRIMARY KEY,
        filename   VARCHAR(255) NOT NULL UNIQUE,
        applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
");

// ── Helpers ───────────────────────────────────────────────────────────────
function getApplied(PDO $db): array {
    return $db->query("SELECT filename FROM migrations ORDER BY filename")
              ->fetchAll(PDO::FETCH_COLUMN);
}

function getMigrationFiles(): array {
    $dir   = __DIR__ . '/../migrations';
    $files = glob($dir . '/*.sql');
    sort($files);
    return $files;
}

function printLine(string $msg, string $color = ''): void {
    $colors = ['green' => "\033[32m", 'red' => "\033[31m", 'yellow' => "\033[33m", 'reset' => "\033[0m"];
    $isCli  = PHP_SAPI === 'cli';
    if ($isCli && $color && isset($colors[$color])) {
        echo $colors[$color] . $msg . $colors['reset'] . PHP_EOL;
    } else {
        echo $msg . PHP_EOL;
    }
}

// ── Commands ──────────────────────────────────────────────────────────────
if ($command === 'status') {
    $applied = getApplied($db);
    $files   = getMigrationFiles();
    printLine("\nMigration Status:", 'yellow');
    printLine(str_repeat('-', 50));
    foreach ($files as $file) {
        $name = basename($file);
        $done = in_array($name, $applied);
        printLine(($done ? '  [✓] ' : '  [ ] ') . $name, $done ? 'green' : 'red');
    }
    printLine(str_repeat('-', 50));
    $pending = count(array_filter($files, fn($f) => !in_array(basename($f), $applied)));
    printLine("  Pending: $pending migration(s)" . ($pending ? '' : ' — all up to date!'), $pending ? 'yellow' : 'green');
    echo PHP_EOL;
    exit(0);
}

if ($command === 'migrate') {
    $applied = getApplied($db);
    $files   = getMigrationFiles();
    $ran     = 0;

    printLine("\nRunning migrations...", 'yellow');

    foreach ($files as $file) {
        $name = basename($file);

        if (in_array($name, $applied)) {
            printLine("  [skip] $name");
            continue;
        }

        $sql = file_get_contents($file);
        // Strip single-line comments and split on semicolons
        $statements = array_filter(
            array_map('trim', explode(';', preg_replace('/--[^\n]*/', '', $sql))),
            fn($s) => $s !== ''
        );

        // MySQL DDL (ALTER TABLE) causes implicit commit, so we run each statement
        // individually. Error codes we treat as harmless (already-applied by
        // controller auto-migrations):
        //   1060 — Duplicate column name
        //   1061 — Duplicate key name
        //   1091 — Can't DROP; check column/key exists
        $harmless = [1060, 1061, 1091];
        $failed   = false;

        foreach ($statements as $stmt) {
            try {
                $db->exec($stmt);
            } catch (PDOException $e) {
                $code = (int)$e->errorInfo[1];
                if (in_array($code, $harmless)) {
                    printLine("  [warn] $name — already applied: " . $e->getMessage(), 'yellow');
                } else {
                    printLine("  [FAIL] $name — " . $e->getMessage(), 'red');
                    $failed = true;
                    break;
                }
            }
        }

        if ($failed) {
            exit(1);
        }

        try {
            $db->prepare("INSERT INTO migrations (filename) VALUES (?)")->execute([$name]);
        } catch (PDOException $e) { /* already recorded */ }
        printLine("  [done] $name", 'green');
        $ran++;
    }

    echo PHP_EOL;
    if ($ran === 0) {
        printLine("Nothing to migrate — database is up to date.", 'green');
    } else {
        printLine("Done. $ran migration(s) applied.", 'green');
    }
    echo PHP_EOL;
    exit(0);
}

printLine("Unknown command: $command. Use: migrate | status", 'red');
exit(1);
