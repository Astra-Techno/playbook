<?php
/**
 * Seed script: creates sample users, venues, bookings, and reviews.
 * Run via: php seed.php (or visit /api/seed if routed)
 *
 * Uses direct DB access to insert test data.
 */
require_once __DIR__ . '/config/database.php';

header('Content-Type: application/json');

$db = Database::getConnection();

// --- Helper ---
function generateToken(): string {
    return bin2hex(random_bytes(32));
}

// --- 1. Create test users ---
$users = [
    ['name' => 'Ravi Kumar',     'phone' => '9900000001', 'role' => 'user'],
    ['name' => 'Priya Sharma',   'phone' => '9900000002', 'role' => 'user'],
    ['name' => 'Arun Prakash',   'phone' => '9900000003', 'role' => 'user'],
    ['name' => 'Deepa Menon',    'phone' => '9900000004', 'role' => 'user'],
    ['name' => 'Venue Owner 1',  'phone' => '9900000010', 'role' => 'user'],
    ['name' => 'Venue Owner 2',  'phone' => '9900000011', 'role' => 'user'],
];

$userIds = [];
$insertUser = $db->prepare(
    "INSERT IGNORE INTO users (name, phone, role, auth_token, created_at) VALUES (?,?,?,?,NOW())"
);
$findUser = $db->prepare("SELECT id FROM users WHERE phone = ?");

foreach ($users as $u) {
    $insertUser->execute([$u['name'], $u['phone'], $u['role'], generateToken()]);
    $findUser->execute([$u['phone']]);
    $userIds[$u['phone']] = (int) $findUser->fetchColumn();
}

$ownerId1 = $userIds['9900000010'];
$ownerId2 = $userIds['9900000011'];
$playerId1 = $userIds['9900000001'];
$playerId2 = $userIds['9900000002'];
$playerId3 = $userIds['9900000003'];
$playerId4 = $userIds['9900000004'];

echo "Users created: " . json_encode($userIds) . "\n";

// --- 2. Create test venues ---
// Keep the public fixture IDs stable. The E2E suite uses court 2 as the
// primary owner-managed venue, so reserve court 1 for this neutral fixture.
$fixtureCourt = [
    'owner_id' => $ownerId1,
    'name' => 'E2E Reference Court',
    'type' => 'shuttle',
    'location' => 'Chennai',
    'hourly_rate' => 100,
    'description' => 'Reference fixture used to keep automated test IDs stable.',
    'lat' => 13.0500,
    'lng' => 80.2000,
    'open_time' => '06:00',
    'close_time' => '22:00',
    'amenities' => json_encode(['Parking']),
    'is_verified' => 1,
];
$insertFixtureCourt = $db->prepare(
    "INSERT IGNORE INTO courts (owner_id, name, type, location, hourly_rate, description, lat, lng, open_time, close_time, amenities, is_verified, created_at)
     VALUES (?,?,?,?,?,?,?,?,?,?,?,?,NOW())"
);
$insertFixtureCourt->execute([
    $fixtureCourt['owner_id'], $fixtureCourt['name'], $fixtureCourt['type'],
    $fixtureCourt['location'], $fixtureCourt['hourly_rate'], $fixtureCourt['description'],
    $fixtureCourt['lat'], $fixtureCourt['lng'], $fixtureCourt['open_time'],
    $fixtureCourt['close_time'], $fixtureCourt['amenities'], $fixtureCourt['is_verified'],
]);

$venues = [
    [
        'owner_id' => $ownerId1,
        'name' => 'Smash Badminton Arena',
        'type' => 'shuttle',
        'location' => 'Anna Nagar, Chennai',
        'hourly_rate' => 400,
        'description' => 'Premium 4-court badminton facility with wooden flooring, AC, and pro lighting. Equipment rental available.',
        'lat' => 13.0850,
        'lng' => 80.2101,
        'open_time' => '06:00',
        'close_time' => '22:00',
        'amenities' => json_encode(['Parking', 'Floodlights', 'Changing Room', 'Equipment Rental', 'WiFi']),
        'is_verified' => 1,
    ],
    [
        'owner_id' => $ownerId1,
        'name' => 'PowerPlay Cricket Nets',
        'type' => 'cricket',
        'location' => 'T. Nagar, Chennai',
        'hourly_rate' => 600,
        'description' => '6-lane cricket practice nets with bowling machines. Full-size indoor pitch for net sessions.',
        'lat' => 13.0418,
        'lng' => 80.2341,
        'open_time' => '05:00',
        'close_time' => '23:00',
        'amenities' => json_encode(['Parking', 'Floodlights', 'Shower', 'Cafeteria', 'First Aid']),
        'is_verified' => 1,
    ],
    [
        'owner_id' => $ownerId2,
        'name' => 'Urban Tennis Club',
        'type' => 'tennis',
        'location' => 'Adyar, Chennai',
        'hourly_rate' => 800,
        'description' => '2 synthetic courts, 1 clay court. Coaching available. Member tournaments every month.',
        'lat' => 13.0063,
        'lng' => 80.2574,
        'open_time' => '06:00',
        'close_time' => '21:00',
        'amenities' => json_encode(['Parking', 'Floodlights', 'Changing Room', 'Shower', 'Equipment Rental', 'Cafeteria']),
        'is_verified' => 0,
    ],
    [
        'owner_id' => $ownerId2,
        'name' => 'FitZone Gym & Courts',
        'type' => 'gym',
        'location' => 'Velachery, Chennai',
        'hourly_rate' => 300,
        'description' => 'Full gym + indoor basketball court + yoga studio. Day passes available.',
        'lat' => 12.9815,
        'lng' => 80.2180,
        'open_time' => '05:00',
        'close_time' => '22:00',
        'amenities' => json_encode(['Parking', 'Changing Room', 'Shower', 'WiFi', 'First Aid']),
        'is_verified' => 1,
    ],
    [
        'owner_id' => $ownerId1,
        'name' => 'AquaSplash Swimming Pool',
        'type' => 'swimming',
        'location' => 'Porur, Chennai',
        'hourly_rate' => 250,
        'description' => '25m Olympic-standard pool. Kids pool. Heated in winter. Certified lifeguards on duty.',
        'lat' => 13.0382,
        'lng' => 80.1567,
        'open_time' => '06:00',
        'close_time' => '20:00',
        'amenities' => json_encode(['Parking', 'Changing Room', 'Shower', 'Cafeteria', 'First Aid']),
        'is_verified' => 1,
    ],
];

$courtIds = [];
$insertCourt = $db->prepare(
    "INSERT INTO courts (owner_id, name, type, location, hourly_rate, description, lat, lng, open_time, close_time, amenities, is_verified, created_at)
     VALUES (?,?,?,?,?,?,?,?,?,?,?,?,NOW())"
);
// Check existing
$findCourt = $db->prepare("SELECT id FROM courts WHERE name = ? AND owner_id = ?");

foreach ($venues as $v) {
    $findCourt->execute([$v['name'], $v['owner_id']]);
    $existing = $findCourt->fetchColumn();
    if ($existing) {
        $courtIds[] = (int) $existing;
        continue;
    }
    $insertCourt->execute([
        $v['owner_id'], $v['name'], $v['type'], $v['location'],
        $v['hourly_rate'], $v['description'], $v['lat'], $v['lng'],
        $v['open_time'], $v['close_time'], $v['amenities'], $v['is_verified']
    ]);
    $courtIds[] = (int) $db->lastInsertId();
}

echo "Courts created: " . json_encode($courtIds) . "\n";

// --- 3. Create sub-courts for first venue ---
$subCourts = [
    ['court_id' => $courtIds[0], 'name' => 'Court A', 'hourly_rate' => 400],
    ['court_id' => $courtIds[0], 'name' => 'Court B', 'hourly_rate' => 400],
    ['court_id' => $courtIds[0], 'name' => 'Court C (Premium)', 'hourly_rate' => 600],
];

$insertSub = $db->prepare(
    "INSERT IGNORE INTO sub_courts (court_id, name, hourly_rate, created_at) VALUES (?,?,?,NOW())"
);
foreach ($subCourts as $sc) {
    $insertSub->execute([$sc['court_id'], $sc['name'], $sc['hourly_rate']]);
}
echo "Sub-courts created for court {$courtIds[0]}\n";

// --- 4. Create bookings (today, tomorrow, past) ---
$today = date('Y-m-d');
$tomorrow = date('Y-m-d', strtotime('+1 day'));
$yesterday = date('Y-m-d', strtotime('-1 day'));
$twoDaysAgo = date('Y-m-d', strtotime('-2 days'));

$bookings = [
    // Today's bookings
    ['user_id' => $playerId1, 'court_id' => $courtIds[0], 'date' => $today, 'start' => '09:00', 'end' => '10:00', 'price' => 400],
    ['user_id' => $playerId2, 'court_id' => $courtIds[0], 'date' => $today, 'start' => '10:00', 'end' => '11:00', 'price' => 400],
    ['user_id' => $playerId3, 'court_id' => $courtIds[0], 'date' => $today, 'start' => '17:00', 'end' => '18:00', 'price' => 400],
    ['user_id' => $playerId1, 'court_id' => $courtIds[1], 'date' => $today, 'start' => '14:00', 'end' => '15:00', 'price' => 600],
    // Tomorrow's bookings
    ['user_id' => $playerId2, 'court_id' => $courtIds[2], 'date' => $tomorrow, 'start' => '08:00', 'end' => '09:00', 'price' => 800],
    ['user_id' => $playerId4, 'court_id' => $courtIds[3], 'date' => $tomorrow, 'start' => '06:00', 'end' => '07:00', 'price' => 300],
    // Past bookings (for "Book Again" and review prompt testing)
    ['user_id' => $playerId1, 'court_id' => $courtIds[0], 'date' => $yesterday, 'start' => '08:00', 'end' => '09:00', 'price' => 400],
    ['user_id' => $playerId1, 'court_id' => $courtIds[2], 'date' => $twoDaysAgo, 'start' => '16:00', 'end' => '17:00', 'price' => 800],
    ['user_id' => $playerId2, 'court_id' => $courtIds[1], 'date' => $yesterday, 'start' => '10:00', 'end' => '11:00', 'price' => 600],
    ['user_id' => $playerId3, 'court_id' => $courtIds[4], 'date' => $twoDaysAgo, 'start' => '07:00', 'end' => '08:00', 'price' => 250],
];

$insertBooking = $db->prepare(
    "INSERT INTO bookings (user_id, court_id, start_time, end_time, type, total_price, status, created_at)
     VALUES (?,?,?,?,?,?,?,NOW())"
);

$bookingCount = 0;
foreach ($bookings as $b) {
    $start = "{$b['date']} {$b['start']}:00";
    $end = "{$b['date']} {$b['end']}:00";
    // Check for duplicate
    $chk = $db->prepare("SELECT id FROM bookings WHERE court_id=? AND start_time=? AND status='confirmed'");
    $chk->execute([$b['court_id'], $start]);
    if ($chk->fetch()) continue;

    $insertBooking->execute([$b['user_id'], $b['court_id'], $start, $end, 'hourly', $b['price'], 'confirmed']);
    $bookingCount++;
}
echo "Bookings created: $bookingCount\n";

// --- 5. Create reviews ---
$reviews = [
    ['court_id' => $courtIds[0], 'user_id' => $playerId1, 'rating' => 5, 'comment' => 'Best badminton courts in Chennai! Great lighting and wooden flooring.'],
    ['court_id' => $courtIds[0], 'user_id' => $playerId2, 'rating' => 4, 'comment' => 'Good courts but parking is limited during peak hours.'],
    ['court_id' => $courtIds[0], 'user_id' => $playerId3, 'rating' => 5, 'comment' => 'Love playing here. Courts are well maintained.'],
    ['court_id' => $courtIds[1], 'user_id' => $playerId1, 'rating' => 4, 'comment' => 'Great nets practice. Bowling machine is accurate.'],
    ['court_id' => $courtIds[1], 'user_id' => $playerId4, 'rating' => 3, 'comment' => 'Decent facility but a bit pricey for the area.'],
    ['court_id' => $courtIds[2], 'user_id' => $playerId2, 'rating' => 5, 'comment' => 'The clay court is exceptional. Coaching staff is very professional.'],
    ['court_id' => $courtIds[3], 'user_id' => $playerId3, 'rating' => 4, 'comment' => 'Nice gym with good basketball court. Day pass is a good option.'],
    ['court_id' => $courtIds[4], 'user_id' => $playerId4, 'rating' => 5, 'comment' => 'Clean pool, good lifeguards. My kids love it here.'],
    ['court_id' => $courtIds[4], 'user_id' => $playerId1, 'rating' => 4, 'comment' => 'Great pool but gets crowded on weekends.'],
];

$insertReview = $db->prepare(
    "INSERT IGNORE INTO reviews (court_id, user_id, rating, comment, created_at) VALUES (?,?,?,?,NOW())"
);
$reviewCount = 0;
foreach ($reviews as $r) {
    try {
        $insertReview->execute([$r['court_id'], $r['user_id'], $r['rating'], $r['comment']]);
        $reviewCount++;
    } catch (\PDOException $e) {
        // Skip duplicate
    }
}
echo "Reviews created: $reviewCount\n";

// --- 6. Create blocked slots (for testing slot picker) ---
$insertBlock = $db->prepare(
    "INSERT INTO blocked_slots (court_id, start_time, end_time, reason, block_kind, blocked_by, created_at)
     VALUES (?,?,?,?,?,?,NOW())"
);
// Block a maintenance slot tomorrow
try {
    $insertBlock->execute([
        $courtIds[0],
        "$tomorrow 12:00:00",
        "$tomorrow 14:00:00",
        'Maintenance',
        'maintenance',
        $ownerId1
    ]);
    echo "Blocked slot created for maintenance\n";
} catch (\PDOException $e) {}

// --- 7. Create some favorites ---
$insertFav = $db->prepare("INSERT IGNORE INTO favorites (user_id, court_id, created_at) VALUES (?,?,NOW())");
$insertFav->execute([$playerId1, $courtIds[0]]);
$insertFav->execute([$playerId1, $courtIds[2]]);
$insertFav->execute([$playerId2, $courtIds[0]]);
$insertFav->execute([$playerId2, $courtIds[4]]);
echo "Favorites created\n";

// --- 8. Create a notification ---
$insertNotif = $db->prepare(
    "INSERT INTO user_notifications (user_id, type, title, body, court_id, created_at) VALUES (?,?,?,?,?,NOW())"
);
$insertNotif->execute([$ownerId1, 'booking', 'New Booking', "Ravi Kumar booked Smash Badminton Arena", $courtIds[0]]);
$insertNotif->execute([$ownerId1, 'review', 'New Review', "Priya Sharma left a 4-star review on Smash Badminton Arena", $courtIds[0]]);
$insertNotif->execute([$playerId1, 'booking', 'Booking Confirmed', "Your booking at Smash Badminton Arena is confirmed", $courtIds[0]]);
echo "Notifications created\n";

echo "\n=== SEED COMPLETE ===\n";
echo "Test accounts (OTP: 1234 in demo mode):\n";
echo "  Players:  9900000001, 9900000002, 9900000003, 9900000004\n";
echo "  Owners:   9900000010, 9900000011\n";
echo "  Venues:   " . count($courtIds) . " venues created\n";
echo "  Bookings: $bookingCount bookings (past + today + tomorrow)\n";
echo "  Reviews:  $reviewCount reviews\n";
