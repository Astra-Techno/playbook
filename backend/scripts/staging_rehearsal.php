<?php
/**
 * Rehearse schema 36 on playbook_staging, then place one booking.
 * Does not connect to the playbook database and does not call Cashfree.
 *
 *   php scripts/staging_rehearsal.php
 */

require_once __DIR__ . '/../config/env.php';

$host = getenv('DB_HOST') ?: '127.0.0.1';
$port = getenv('DB_PORT') ?: '3306';
$user = getenv('DB_USER') ?: 'root';
$pass = getenv('DB_PASS');
if ($pass === false) {
    $pass = '';
}
$staging = 'playbook_staging';

$server = new PDO("mysql:host=$host;port=$port;charset=utf8mb4", $user, $pass, [
    PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
]);
$currentName = getenv('DB_NAME') ?: 'playbook';
if ($currentName === $staging) {
    fwrite(STDERR, "Refusing to run while DB_NAME is already $staging.\n");
    exit(1);
}
$server->exec("CREATE DATABASE IF NOT EXISTS `$staging` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci");

putenv('DB_NAME=' . $staging);
$_ENV['DB_NAME'] = $staging;

require_once __DIR__ . '/../config/database.php';
$db = Database::getConnection();
$connected = (string)$db->query('SELECT DATABASE()')->fetchColumn();
if ($connected !== $staging) {
    fwrite(STDERR, "Connected to $connected instead of $staging.\n");
    exit(1);
}

$version = (int)$db->query('SELECT COALESCE(MAX(version),0) FROM schema_version')->fetchColumn();
$needles = [
    'bookings.collection_method' => "SHOW COLUMNS FROM bookings LIKE 'collection_method'",
    'bookings.attendance' => "SHOW COLUMNS FROM bookings LIKE 'attendance'",
    'booking_holds' => "SHOW TABLES LIKE 'booking_holds'",
    'tournaments' => "SHOW TABLES LIKE 'tournaments'",
    'coaching_sessions' => "SHOW TABLES LIKE 'coaching_sessions'",
    'equipment_items' => "SHOW TABLES LIKE 'equipment_items'",
    'equipment_rentals' => "SHOW TABLES LIKE 'equipment_rentals'",
    'user_notifications.event_key' => "SHOW COLUMNS FROM user_notifications LIKE 'event_key'",
];
$missing = [];
foreach ($needles as $label => $sql) {
    if (!$db->query($sql)->fetchColumn()) {
        $missing[] = $label;
    }
}
if ($version !== 36 || $missing) {
    fwrite(STDERR, "Schema version is $version. Missing: " . ($missing ? implode(', ', $missing) : 'none') . ".\n");
    exit(1);
}

$phone = '9000000191';
$userRow = $db->prepare('SELECT id FROM users WHERE phone = ?');
$userRow->execute([$phone]);
$userId = (int)$userRow->fetchColumn();
if ($userId <= 0) {
    $db->prepare('INSERT INTO users (name, phone, role) VALUES (?, ?, ?)')->execute(['Staging Player', $phone, 'user']);
    $userId = (int)$db->lastInsertId();
}

$courtRow = $db->prepare('SELECT id FROM courts WHERE owner_id = ? AND name = ?');
$courtRow->execute([$userId, 'Staging Court']);
$courtId = (int)$courtRow->fetchColumn();
if ($courtId <= 0) {
    $db->prepare('INSERT INTO courts (owner_id, name, type, hourly_rate) VALUES (?, ?, ?, ?)')->execute([$userId, 'Staging Court', 'badminton', 400]);
    $courtId = (int)$db->lastInsertId();
}

$spaceRow = $db->prepare('SELECT id FROM sub_courts WHERE court_id = ? AND name = ?');
$spaceRow->execute([$courtId, 'Court 1']);
$spaceId = (int)$spaceRow->fetchColumn();
if ($spaceId <= 0) {
    $db->prepare('INSERT INTO sub_courts (court_id, name, hourly_rate) VALUES (?, ?, ?)')->execute([$courtId, 'Court 1', 400]);
    $spaceId = (int)$db->lastInsertId();
}

require_once __DIR__ . '/../src/Controllers/SubCourtController.php';
new SubCourtController();

require_once __DIR__ . '/../src/Models/Booking.php';
$start = '2026-12-20 06:00:00';
$end = '2026-12-20 07:00:00';
$booking = new Booking();
$existing = $db->prepare("SELECT id FROM bookings WHERE court_id = ? AND sub_court_id = ? AND start_time = ? AND end_time = ? AND status = 'confirmed'");
$existing->execute([$courtId, $spaceId, $start, $end]);
$bookingId = (int)$existing->fetchColumn();
if ($bookingId <= 0) {
    $booking->user_id = $userId;
    $booking->court_id = $courtId;
    $booking->sub_court_id = $spaceId;
    $booking->start_time = $start;
    $booking->end_time = $end;
    $booking->type = 'hourly';
    $booking->total_price = 400;
    $booking->collection_method = null;
    if (!$booking->create()) {
        fwrite(STDERR, "The staging booking was not saved.\n");
        exit(1);
    }
    $bookingId = (int)$booking->conn->lastInsertId();
}

$open = $booking->isSlotAvailable($courtId, $start, $end, $spaceId);
if ($open) {
    fwrite(STDERR, "The saved booking did not occupy the court.\n");
    exit(1);
}

echo "database=$connected\n";
echo "schema_version=$version\n";
echo "booking_id=$bookingId\n";
echo "overlap=refused\n";
echo "playbook_left_untouched\n";
