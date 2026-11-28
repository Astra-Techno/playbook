<?php
/**
 * Daily renewal reminders for members: 3 days before a membership ends and on its last day.
 * Run once a day from the server's cron (command line only), for example at 9 AM:
 *   0 9 * * * php /path/to/backend/scripts/membership_reminders.php
 * Safe to run more than once a day: each reminder has a unique event key.
 */
if (PHP_SAPI !== 'cli') {
    http_response_code(403);
    exit('Command line only.');
}

require_once __DIR__ . '/../config/env.php';
require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../src/MembershipCare.php';
require_once __DIR__ . '/../src/Push.php';

$db = Database::getConnection();
MemberCheckIn::ensureSchema($db);
$today = (new DateTimeImmutable('now', new DateTimeZone('Asia/Kolkata')))->format('Y-m-d');
$soon = (new DateTimeImmutable($today))->modify('+2 days')->format('Y-m-d');

$stmt = $db->prepare("
    SELECT us.id, us.user_id, us.court_id, us.end_date, c.name AS venue_name
    FROM user_subscriptions us
    JOIN courts c ON c.id = us.court_id
    WHERE us.status = 'active' AND us.end_date IN (?, ?)
");
$stmt->execute([$today, $soon]);
$ins = $db->prepare('INSERT IGNORE INTO user_notifications (user_id, type, title, body, court_id, event_key) VALUES (?,?,?,?,?,?)');
$sent = 0;
foreach ($stmt->fetchAll(PDO::FETCH_ASSOC) as $sub) {
    $end = substr((string)$sub['end_date'], 0, 10);
    if (!MembershipCare::autoReminderDue($end, $today)) {
        continue;
    }
    $msg = MembershipCare::reminder((string)$sub['venue_name'], $end, $today);
    $ins->execute([(int)$sub['user_id'], 'membership', $msg['title'], $msg['body'], (int)$sub['court_id'], "renew:{$sub['id']}:$end:" . MemberCheckIn::daysLeft($end, $today)]);
    if ($ins->rowCount()) {
        Push::sendToUser((int)$sub['user_id'], $msg['title'], $msg['body'], ['type' => 'membership', 'subscription_id' => (string)$sub['id']]);
        $sent++;
    }
}
echo "Membership reminders sent: $sent\n";
