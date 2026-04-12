<?php

/**
 * Minimal .env loader — no Composer dependency required.
 * Reads KEY=VALUE pairs, strips quotes, skips comments and blank lines.
 * Populates $_ENV and putenv() so getenv() works too.
 */
function loadEnv(string $path): void {
    if (!file_exists($path)) return;

    $lines = file($path, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
    foreach ($lines as $line) {
        $line = trim($line);
        if ($line === '' || $line[0] === '#') continue;
        if (strpos($line, '=') === false)      continue;

        [$key, $value] = explode('=', $line, 2);
        $key   = trim($key);
        $value = trim($value);

        if ($key === '') continue;

        // Quoted value: strip surrounding quotes, use content literally
        // Supports: DB_PASS="$Sp3c!al#Chars" or DB_PASS='$Sp3c!al#Chars'
        if (preg_match('/^(["\'])(.*)\1$/s', $value, $m)) {
            $value = $m[2];
        } else {
            // Unquoted: strip trailing inline comments (e.g.  value  # comment)
            $value = trim(preg_replace('/\s+#.*$/', '', $value));
        }

        $_ENV[$key]  = $value;
        putenv($key . '=' . $value);  // concatenate — safe for any chars in $value
    }
}

loadEnv(__DIR__ . '/../.env');
