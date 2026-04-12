<?php
/**
 * KoCourt – Web Migration Runner
 *
 * Visit: https://kocourt.com/backend/scripts/migrate_web.php?key=YOUR_MIGRATE_KEY
 *
 * Set MIGRATE_KEY in backend/.env — keep it secret, run once after each deploy.
 * Delete or block this file after initial setup if you want extra security.
 */

require_once __DIR__ . '/../config/env.php';

// ── Auth ──────────────────────────────────────────────────────────────────────
$expectedKey = getenv('MIGRATE_KEY') ?: '';
$givenKey    = $_GET['key'] ?? '';

if (!$expectedKey || $givenKey !== $expectedKey) {
    http_response_code(403);
    die('<h2 style="font-family:sans-serif;color:red">403 – Invalid or missing key.<br>
         Set MIGRATE_KEY in backend/.env and pass ?key=YOUR_KEY in the URL.</h2>');
}

require_once __DIR__ . '/../config/database.php';

$db = Database::getConnection();

// Ensure migrations table exists
$db->exec("
    CREATE TABLE IF NOT EXISTS migrations (
        id         INT AUTO_INCREMENT PRIMARY KEY,
        filename   VARCHAR(255) NOT NULL UNIQUE,
        applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
");

$applied = $db->query("SELECT filename FROM migrations ORDER BY filename")->fetchAll(PDO::FETCH_COLUMN);
$files   = glob(__DIR__ . '/../migrations/*.sql');
sort($files);

$ran    = 0;
$errors = [];
$log    = [];

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
        foreach ($statements as $stmt) {
            $db->exec($stmt);
        }
        $db->prepare("INSERT INTO migrations (filename) VALUES (?)")->execute([$name]);
        $db->commit();
        $log[] = ['status' => 'done', 'name' => $name];
        $ran++;
    } catch (PDOException $e) {
        $db->rollBack();
        $log[]    = ['status' => 'fail', 'name' => $name, 'error' => $e->getMessage()];
        $errors[] = $name;
        break; // stop on first failure
    }
}

$allOk = empty($errors);
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>KoCourt – DB Migration</title>
<style>
  body { font-family: -apple-system, sans-serif; max-width: 640px; margin: 40px auto; padding: 0 20px; background: #f8fafc; color: #1e293b; }
  h1   { font-size: 1.4rem; margin-bottom: 4px; }
  .sub { color: #64748b; font-size: .9rem; margin-bottom: 28px; }
  .row { display: flex; align-items: center; gap: 12px; padding: 10px 14px; border-radius: 10px; margin-bottom: 6px; font-size: .9rem; background: white; border: 1px solid #e2e8f0; }
  .badge { font-size: .72rem; font-weight: 700; padding: 3px 10px; border-radius: 999px; text-transform: uppercase; letter-spacing: .04em; flex-shrink: 0; }
  .done { background: #dcfce7; color: #166534; }
  .skip { background: #f1f5f9; color: #64748b; }
  .fail { background: #fee2e2; color: #991b1b; }
  .err  { font-size: .8rem; color: #991b1b; margin-top: 4px; }
  .banner { padding: 16px 20px; border-radius: 12px; margin-top: 24px; font-weight: 600; }
  .ok  { background: #dcfce7; color: #166534; border: 1px solid #bbf7d0; }
  .bad { background: #fee2e2; color: #991b1b; border: 1px solid #fecaca; }
</style>
</head>
<body>
  <h1>🛢️ KoCourt DB Migration</h1>
  <p class="sub">Running on: <strong><?= htmlspecialchars($_SERVER['HTTP_HOST']) ?></strong> &nbsp;·&nbsp; <?= date('Y-m-d H:i:s') ?></p>

  <?php foreach ($log as $entry): ?>
    <div class="row">
      <span class="badge <?= $entry['status'] ?>"><?= $entry['status'] ?></span>
      <span><?= htmlspecialchars($entry['name']) ?></span>
      <?php if (!empty($entry['error'])): ?>
        <div class="err">↳ <?= htmlspecialchars($entry['error']) ?></div>
      <?php endif ?>
    </div>
  <?php endforeach ?>

  <div class="banner <?= $allOk ? 'ok' : 'bad' ?>">
    <?php if ($allOk && $ran === 0): ?>
      ✅ Database is already up to date — nothing to migrate.
    <?php elseif ($allOk): ?>
      ✅ <?= $ran ?> migration<?= $ran > 1 ? 's' : '' ?> applied successfully.
    <?php else: ?>
      ❌ Migration failed on <strong><?= htmlspecialchars(end($errors)) ?></strong>. Fix the error and re-run.
    <?php endif ?>
  </div>
</body>
</html>
