<?php
/**
 * KoCourt – One-Click Deployer
 *
 * Place this file at the ROOT of your hosting (public_html/deploy.php).
 * Visit: https://kocourt.com/deploy.php?key=YOUR_DEPLOY_KEY
 *
 * What it does:
 *   1. Downloads latest code from GitHub
 *   2. Updates backend PHP files
 *   3. Updates frontend (built) files
 *   4. Runs any pending DB migrations
 *
 * Set DEPLOY_KEY in backend/.env  (e.g. DEPLOY_KEY=some_random_secret_here)
 * Set GITHUB_REPO in backend/.env (e.g. GITHUB_REPO=Astra-Techno/playbook)
 * Set GITHUB_BRANCH in backend/.env (optional, default: main)
 * Set GITHUB_TOKEN in backend/.env  (only needed for private repos)
 */

ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

// ── Bootstrap ────────────────────────────────────────────────────────────────
define('BASE_DIR',    __DIR__);
define('BACKEND_DIR', BASE_DIR . '/backend');
define('START_TIME',  microtime(true));

// Load .env
$envFile = BACKEND_DIR . '/.env';
if (file_exists($envFile)) {
    foreach (file($envFile) as $line) {
        $line = trim($line);
        if (!$line || $line[0] === '#') continue;
        if (strpos($line, '=') !== false) {
            [$k, $v] = explode('=', $line, 2);
            $_ENV[trim($k)] = trim($v, " \t\n\r\0\x0B\"'");
        }
    }
}

// ── Auth ─────────────────────────────────────────────────────────────────────
$deployKey = $_ENV['DEPLOY_KEY'] ?? '';
$givenKey  = $_GET['key'] ?? '';

header('Content-Type: text/html; charset=UTF-8');

if (!$deployKey || $givenKey !== $deployKey) {
    http_response_code(403);
    die(page('Access Denied', '<div class="err">403 – Invalid or missing key.<br>Set DEPLOY_KEY in backend/.env</div>'));
}

// ── Config ───────────────────────────────────────────────────────────────────
$repo   = $_ENV['GITHUB_REPO']   ?? 'Astra-Techno/playbook';
$branch = $_ENV['GITHUB_BRANCH'] ?? 'main';
$token  = $_ENV['GITHUB_TOKEN']  ?? '';

// ── Run ──────────────────────────────────────────────────────────────────────
$log = [];

function log_step(string $icon, string $msg, string $type = 'info'): void {
    global $log;
    $log[] = ['icon' => $icon, 'msg' => $msg, 'type' => $type];
    ob_flush(); flush();
}

function abort(string $msg): void {
    log_step('✗', $msg, 'err');
    echo render_log();
    echo render_banner(false, $msg);
    echo '</body></html>';
    exit;
}

// ────────────────────────────────────────────────────────────────────────────
// STEP 1 — Download repo ZIP from GitHub
// ────────────────────────────────────────────────────────────────────────────
log_step('⬇', "Downloading <strong>{$repo}@{$branch}</strong> from GitHub…");

$zipUrl = "https://github.com/{$repo}/archive/refs/heads/{$branch}.zip";
$opts   = ['http' => [
    'method'          => 'GET',
    'timeout'         => 60,
    'follow_location' => 1,
    'header'          => implode("\r\n", array_filter([
        'User-Agent: KoCourt-Deployer/1.0',
        $token ? "Authorization: Bearer {$token}" : '',
    ])),
]];

// Try cURL first (works even when allow_url_fopen is off)
$zipData = false;
if (function_exists('curl_init')) {
    $ch = curl_init($zipUrl);
    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_FOLLOWLOCATION => true,
        CURLOPT_TIMEOUT        => 60,
        CURLOPT_SSL_VERIFYPEER => true,
        CURLOPT_USERAGENT      => 'KoCourt-Deployer/1.0',
        CURLOPT_HTTPHEADER     => array_filter([
            $token ? "Authorization: Bearer {$token}" : null,
        ]),
    ]);
    $zipData  = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $curlErr  = curl_error($ch);
    if (PHP_VERSION_ID < 80100) curl_close($ch);
    if ($httpCode === 404) abort("Repo not found (404). Is the repo private? Add GITHUB_TOKEN to backend/.env");
    if ($httpCode === 401 || $httpCode === 403) abort("GitHub auth failed ({$httpCode}). Add GITHUB_TOKEN to backend/.env");
    if ($httpCode !== 200) abort("GitHub returned HTTP {$httpCode}. cURL error: {$curlErr}");
} else {
    $zipData = @file_get_contents($zipUrl, false, stream_context_create($opts));
}

if (!$zipData) {
    abort("Failed to download ZIP. Enable cURL or allow_url_fopen on this server.");
}
log_step('✓', 'Download complete (' . round(strlen($zipData) / 1024) . ' KB)', 'ok');

// ────────────────────────────────────────────────────────────────────────────
// STEP 2 — Extract to temp dir
// ────────────────────────────────────────────────────────────────────────────
log_step('📦', 'Extracting ZIP…');

$tmpZip = sys_get_temp_dir() . '/kocourt_deploy_' . time() . '.zip';
$tmpDir = sys_get_temp_dir() . '/kocourt_extract_' . time();

file_put_contents($tmpZip, $zipData);
unset($zipData); // free memory

$zip = new ZipArchive();
if ($zip->open($tmpZip) !== true) {
    @unlink($tmpZip);
    abort('Failed to open ZIP archive. ZipArchive extension may be missing.');
}
$zip->extractTo($tmpDir);
$zip->close();
@unlink($tmpZip);

// GitHub ZIP root folder is like: Astra-Techno-playbook-abc1234/
$extractedDirs = glob($tmpDir . '/*', GLOB_ONLYDIR);
if (empty($extractedDirs)) {
    rrmdir($tmpDir);
    abort('ZIP extraction failed — no directories found.');
}
$repoRoot = $extractedDirs[0]; // e.g. /tmp/kocourt_extract_xxx/Astra-Techno-playbook-abc123

log_step('✓', 'Extracted to temp directory', 'ok');

// ────────────────────────────────────────────────────────────────────────────
// STEP 3 — Update backend files
// ────────────────────────────────────────────────────────────────────────────
log_step('🔧', 'Updating backend files…');

$srcBackend = $repoRoot . '/backend';
if (!is_dir($srcBackend)) {
    cleanup($tmpDir);
    abort('backend/ folder not found in repo. Check GITHUB_REPO.');
}

// Copy backend files — preserve existing .env (never overwrite secrets)
rcopy($srcBackend, BACKEND_DIR, ['.env']);
log_step('✓', 'Backend files updated', 'ok');

// ────────────────────────────────────────────────────────────────────────────
// STEP 4 — Update frontend files
// ────────────────────────────────────────────────────────────────────────────
log_step('🌐', 'Updating frontend files…');

$srcFrontend = $repoRoot . '/public_html';
if (!is_dir($srcFrontend)) {
    log_step('⚠', 'public_html/ not found in repo — skipping frontend update. Run build_prod.bat and push first.', 'warn');
} else {
    // Copy frontend — preserve deploy.php and backend/ dir
    rcopy($srcFrontend, BASE_DIR, ['deploy.php', 'backend']);
    log_step('✓', 'Frontend files updated', 'ok');
}

// Also copy root .htaccess if present
$srcHtaccess = $repoRoot . '/.htaccess';
if (file_exists($srcHtaccess)) {
    copy($srcHtaccess, BASE_DIR . '/.htaccess');
    log_step('✓', '.htaccess updated', 'ok');
}

// ────────────────────────────────────────────────────────────────────────────
// STEP 5 — Run DB migrations
// ────────────────────────────────────────────────────────────────────────────
log_step('🛢', 'Running database migrations…');

$migrationLog = runMigrations();
foreach ($migrationLog as $m) {
    log_step(
        $m['status'] === 'done' ? '✓' : ($m['status'] === 'skip' ? '·' : '✗'),
        $m['name'] . ($m['error'] ?? ''),
        $m['status'] === 'done' ? 'ok' : ($m['status'] === 'fail' ? 'err' : 'muted')
    );
}

// ────────────────────────────────────────────────────────────────────────────
// Cleanup
// ────────────────────────────────────────────────────────────────────────────
cleanup($tmpDir);

$elapsed = round(microtime(true) - START_TIME, 1);
log_step('🏁', "Deployment completed in {$elapsed}s", 'ok');

// ── Output ───────────────────────────────────────────────────────────────────
$hasError = count(array_filter($log, fn($l) => $l['type'] === 'err')) > 0;
echo page('Deploy', render_log() . render_banner(!$hasError, $hasError ? 'Deployment finished with errors.' : 'Deployment successful!'));

// ═════════════════════════════════════════════════════════════════════════════
// Helpers
// ═════════════════════════════════════════════════════════════════════════════

function runMigrations(): array {
    $log = [];
    try {
        require_once BACKEND_DIR . '/config/database.php';
        $db = Database::getConnection();

        $db->exec("CREATE TABLE IF NOT EXISTS migrations (
            id INT AUTO_INCREMENT PRIMARY KEY,
            filename VARCHAR(255) NOT NULL UNIQUE,
            applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )");

        $applied = $db->query("SELECT filename FROM migrations ORDER BY filename")
                      ->fetchAll(PDO::FETCH_COLUMN);

        $files = glob(BACKEND_DIR . '/migrations/*.sql');
        sort($files);

        foreach ($files as $file) {
            $name = basename($file);
            if (in_array($name, $applied)) {
                $log[] = ['status' => 'skip', 'name' => $name];
                continue;
            }
            $sql        = file_get_contents($file);
            $statements = array_filter(
                array_map('trim', explode(';', preg_replace('/--[^\n]*/', '', $sql))),
                fn($s) => $s !== ''
            );
            try {
                $db->beginTransaction();
                foreach ($statements as $stmt) { $db->exec($stmt); }
                $db->prepare("INSERT INTO migrations (filename) VALUES (?)")->execute([$name]);
                $db->commit();
                $log[] = ['status' => 'done', 'name' => $name];
            } catch (PDOException $e) {
                $db->rollBack();
                $log[] = ['status' => 'fail', 'name' => $name, 'error' => ' — ' . $e->getMessage()];
                break;
            }
        }
    } catch (Throwable $e) {
        $log[] = ['status' => 'fail', 'name' => 'DB connection', 'error' => ' — ' . $e->getMessage()];
    }
    return $log;
}

/** Recursive copy, skipping listed names */
function rcopy(string $src, string $dst, array $skip = []): void {
    if (!is_dir($dst)) mkdir($dst, 0755, true);
    foreach (new DirectoryIterator($src) as $item) {
        if ($item->isDot()) continue;
        if (in_array($item->getFilename(), $skip)) continue;
        $srcPath = $item->getPathname();
        $dstPath = $dst . '/' . $item->getFilename();
        if ($item->isDir()) {
            rcopy($srcPath, $dstPath, []);
        } else {
            copy($srcPath, $dstPath);
        }
    }
}

/** Recursive remove */
function rrmdir(string $dir): void {
    if (!is_dir($dir)) return;
    foreach (new DirectoryIterator($dir) as $item) {
        if ($item->isDot()) continue;
        $item->isDir() ? rrmdir($item->getPathname()) : unlink($item->getPathname());
    }
    rmdir($dir);
}

function cleanup(string $tmpDir): void {
    rrmdir($tmpDir);
}

function render_log(): string {
    global $log;
    $rows = '';
    foreach ($log as $l) {
        $cls  = ['ok' => 'ok', 'err' => 'err', 'warn' => 'warn', 'muted' => 'muted', 'info' => ''][$l['type']] ?? '';
        $rows .= "<div class=\"row {$cls}\"><span class=\"ic\">{$l['icon']}</span><span>{$l['msg']}</span></div>";
    }
    return $rows;
}

function render_banner(bool $ok, string $msg): string {
    $cls = $ok ? 'ok' : 'err';
    return "<div class=\"banner {$cls}\">".($ok ? '✅' : '❌')." {$msg}</div>";
}

function page(string $title, string $body): string {
    $host = $_SERVER['HTTP_HOST'] ?? 'localhost';
    $now  = date('Y-m-d H:i:s');
    return <<<HTML
<!DOCTYPE html><html lang="en"><head>
<meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>KoCourt Deploy – {$title}</title>
<style>
  body{font-family:-apple-system,sans-serif;max-width:680px;margin:36px auto;padding:0 20px;background:#f8fafc;color:#1e293b}
  h1{font-size:1.3rem;margin:0 0 4px}
  .sub{color:#64748b;font-size:.85rem;margin-bottom:24px}
  .row{display:flex;align-items:flex-start;gap:10px;padding:9px 14px;border-radius:9px;margin-bottom:4px;font-size:.88rem;background:white;border:1px solid #e2e8f0}
  .row.ok{border-color:#bbf7d0;background:#f0fdf4}
  .row.err{border-color:#fecaca;background:#fff5f5}
  .row.warn{border-color:#fde68a;background:#fffbeb}
  .row.muted{opacity:.55}
  .ic{flex-shrink:0;width:18px;text-align:center}
  .banner{padding:14px 18px;border-radius:10px;margin-top:20px;font-weight:600;font-size:.95rem}
  .banner.ok{background:#dcfce7;color:#166534;border:1px solid #bbf7d0}
  .banner.err{background:#fee2e2;color:#991b1b;border:1px solid #fecaca}
</style></head><body>
<h1>🚀 KoCourt Deployer</h1>
<p class="sub">{$host} &nbsp;·&nbsp; {$now}</p>
{$body}
</body></html>
HTML;
}
