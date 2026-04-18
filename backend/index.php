<?php

// ── Error reporting (reads APP_DEBUG from .env) ───────────────────────────
// Set APP_DEBUG=false in production .env to silence errors
$_debugEnv = @file_get_contents(__DIR__ . '/.env') ?: '';
$_debug    = !preg_match('/APP_DEBUG\s*=\s*false/i', $_debugEnv);

if ($_debug) {
    ini_set('display_errors', 1);
    ini_set('display_startup_errors', 1);
    error_reporting(E_ALL);
} else {
    ini_set('display_errors', 0);
    error_reporting(0);
}

// Global exception handler — always returns JSON, never raw HTML
set_exception_handler(function (Throwable $e) use ($_debug) {
    if (!headers_sent()) {
        http_response_code(500);
        header('Content-Type: application/json; charset=UTF-8');
    }
    $payload = ['status' => 'error', 'message' => $e->getMessage()];
    if ($_debug) {
        $payload['exception'] = get_class($e);
        $payload['file']      = str_replace(__DIR__, '', $e->getFile());
        $payload['line']      = $e->getLine();
        $payload['trace']     = array_map(
            function ($f) {
                return (isset($f['file']) ? str_replace(__DIR__, '', $f['file']) : '') .
                       (isset($f['line']) ? ':' . $f['line'] : '') . ' ' .
                       (isset($f['class']) ? $f['class'] . '::' : '') .
                       (isset($f['function']) ? $f['function'] : '');
            },
            array_slice($e->getTrace(), 0, 8)
        );
    }
    echo json_encode($payload);
    exit();
});

// Convert fatal PHP errors to exceptions so they get caught above
register_shutdown_function(function () use ($_debug) {
    $err = error_get_last();
    if ($err && in_array($err['type'], [E_ERROR, E_PARSE, E_CORE_ERROR, E_COMPILE_ERROR])) {
        if (!headers_sent()) {
            http_response_code(500);
            header('Content-Type: application/json; charset=UTF-8');
        }
        $payload = ['status' => 'error', 'message' => 'Fatal error: ' . $err['message']];
        if ($_debug) {
            $payload['file'] = str_replace(__DIR__, '', $err['file']);
            $payload['line'] = $err['line'];
        }
        echo json_encode($payload);
    }
});

// ─────────────────────────────────────────────────────────────────────────────

header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Cache-Control: no-store, no-cache, must-revalidate");
header("Pragma: no-cache");
header("Access-Control-Allow-Methods: OPTIONS,GET,POST,PUT,DELETE");
header("Access-Control-Max-Age: 3600");
header("Access-Control-Allow-Headers: Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With, X-HTTP-Method-Override");

// Method tunneling — LiteSpeed blocks DELETE/PUT at server level,
// so the frontend sends POST + X-HTTP-Method-Override header instead.
$methodOverride = $_SERVER['HTTP_X_HTTP_METHOD_OVERRIDE'] ?? '';
if ($methodOverride && in_array(strtoupper($methodOverride), ['DELETE', 'PUT', 'PATCH'])) {
    $_SERVER['REQUEST_METHOD'] = strtoupper($methodOverride);
}

if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once __DIR__ . '/config/database.php';
require_once __DIR__ . '/src/Auth.php';

$uri = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);

// Strip the script's directory prefix (e.g. /backend)
$base_dir = rtrim(dirname($_SERVER['SCRIPT_NAME']), '/\\');
if ($base_dir !== '' && strpos($uri, $base_dir) === 0) {
    $uri = substr($uri, strlen($base_dir));
}

// Also strip /api prefix — requests routed via root .htaccess RewriteRule ^api/(.*)$
// keep REQUEST_URI as /api/... so we need to remove that prefix here
if (strpos($uri, '/api/') === 0) {
    $uri = substr($uri, 4);
} elseif ($uri === '/api') {
    $uri = '/';
}

// Split into segments; $seg[0] = first path part (e.g. 'auth', 'courts')
$seg = array_values(array_filter(explode('/', $uri), 'strlen'));

// Test / DB status endpoint
if (isset($seg[0]) && $seg[0] === 'test') {
    $start = microtime(true);
    try {
        $db = Database::getConnection();

        // MySQL version
        $version = $db->query("SELECT VERSION() AS v")->fetchColumn();

        // Ping latency
        $db->query("SELECT 1");
        $latency = round((microtime(true) - $start) * 1000, 2);

        // Tables in current DB
        $tables = $db->query("SHOW TABLES")->fetchAll(PDO::FETCH_COLUMN);

        // Row counts per table
        $counts = [];
        foreach ($tables as $t) {
            $counts[$t] = (int)$db->query("SELECT COUNT(*) FROM `$t`")->fetchColumn();
        }

        echo json_encode([
            "status"       => "ok",
            "message"      => "Database connected successfully",
            "host"         => getenv('DB_HOST') ?: 'localhost',
            "port"         => getenv('DB_PORT') ?: '3306',
            "database"     => getenv('DB_NAME') ?: 'playbook',
            "mysql_version"=> $version,
            "latency_ms"   => $latency,
            "tables"       => $counts,
            "php_version"  => PHP_VERSION,
            "server_time"  => date('Y-m-d H:i:s'),
        ]);
    } catch (Exception $e) {
        http_response_code(500);
        echo json_encode([
            "status"  => "error",
            "message" => $e->getMessage(),
            "host"    => getenv('DB_HOST') ?: 'localhost',
            "port"    => getenv('DB_PORT') ?: '3306',
        ]);
    }
    exit();
}

// Upload Route
if (isset($seg[0]) && $seg[0] === 'upload') {
    if ($_SERVER['REQUEST_METHOD'] === 'POST') {
        $file = $_FILES['image'] ?? null;
        if (!$file || $file['error'] !== UPLOAD_ERR_OK) {
            http_response_code(400);
            echo json_encode(['message' => 'No file or upload error.']);
            exit();
        }
        $finfo = finfo_open(FILEINFO_MIME_TYPE);
        $mime  = finfo_file($finfo, $file['tmp_name']);
        finfo_close($finfo);
        $allowed = ['image/jpeg' => 'jpg', 'image/png' => 'png', 'image/webp' => 'webp'];
        if (!array_key_exists($mime, $allowed)) {
            http_response_code(400);
            echo json_encode(['message' => 'Invalid file type. JPG, PNG, WebP only.']);
            exit();
        }
        if ($file['size'] > 5 * 1024 * 1024) {
            http_response_code(400);
            echo json_encode(['message' => 'File too large. Max 5 MB.']);
            exit();
        }
        $uploads_dir = __DIR__ . '/uploads/';
        if (!is_dir($uploads_dir)) {
            mkdir($uploads_dir, 0755, true);
        }
        $filename = 'court_' . bin2hex(random_bytes(8)) . '.' . $allowed[$mime];
        if (move_uploaded_file($file['tmp_name'], $uploads_dir . $filename)) {
            $protocol   = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https' : 'http';
            $script_dir = rtrim(dirname($_SERVER['SCRIPT_NAME']), '/\\');
            $url = $protocol . '://' . $_SERVER['HTTP_HOST'] . $script_dir . '/uploads/' . $filename;
            http_response_code(200);
            echo json_encode(['url' => $url]);
        } else {
            http_response_code(500);
            echo json_encode(['message' => 'Failed to save file.']);
        }
    } else {
        http_response_code(405);
        echo json_encode(['message' => 'Method not allowed.']);
    }
    exit();
}

// Payment Routes
if (isset($seg[0]) && $seg[0] === 'payments') {
    require_once __DIR__ . '/src/Controllers/PaymentController.php';
    $paymentController = new PaymentController();

    if (isset($seg[1]) && $seg[1] === 'config' && $_SERVER['REQUEST_METHOD'] === 'GET') {
        $paymentController->config();
        exit();
    }
    if (isset($seg[1]) && $seg[1] === 'create-order' && $_SERVER['REQUEST_METHOD'] === 'POST') {
        Auth::require();
        $paymentController->createOrder();
        exit();
    }
    if (isset($seg[1]) && $seg[1] === 'verify' && $_SERVER['REQUEST_METHOD'] === 'POST') {
        Auth::require();
        $paymentController->verify();
        exit();
    }
    http_response_code(404);
    echo json_encode(['message' => 'Payment endpoint not found']);
    exit();
}

// Auth Routes
if (isset($seg[0]) && $seg[0] === 'auth') {
    require_once __DIR__ . '/src/Controllers/AuthController.php';
    $authController = new AuthController();

    if (isset($seg[1]) && $seg[1] === 'send-otp' && $_SERVER['REQUEST_METHOD'] === 'POST') {
        $authController->sendOtp(); exit();
    }
    if (isset($seg[1]) && $seg[1] === 'check-phone' && $_SERVER['REQUEST_METHOD'] === 'POST') {
        $authController->checkPhone(); exit();
    }
    if (isset($seg[1]) && $seg[1] === 'verify-otp' && $_SERVER['REQUEST_METHOD'] === 'POST') {
        $authController->verifyOtp(); exit();
    }
    if (isset($seg[1]) && $seg[1] === 'profile' && $_SERVER['REQUEST_METHOD'] === 'PUT') {
        Auth::require();
        $authController->updateProfile(); exit();
    }
    if (isset($seg[1]) && $seg[1] === 'profile' && $_SERVER['REQUEST_METHOD'] === 'GET') {
        Auth::require();
        $authController->getProfile(); exit();
    }
}

// Court Routes
if (isset($seg[0]) && $seg[0] === 'courts') {
    require_once __DIR__ . '/src/Controllers/CourtController.php';
    $courtController = new CourtController();

    if ($_SERVER['REQUEST_METHOD'] === 'GET' && isset($seg[1]) && is_numeric($seg[1]) && !isset($seg[2])) { $courtController->show((int)$seg[1]); exit(); }
    if ($_SERVER['REQUEST_METHOD'] === 'GET') { $courtController->index(); exit(); }
    // GET  /courts/claims          — list all claims (admin)
    if ($_SERVER['REQUEST_METHOD'] === 'GET'  && isset($seg[1]) && $seg[1] === 'claims') { $courtController->listClaims(); exit(); }
    // PUT  /courts/claims/:id/approve
    if ($_SERVER['REQUEST_METHOD'] === 'PUT'  && isset($seg[1]) && $seg[1] === 'claims' && isset($seg[2]) && isset($seg[3]) && $seg[3] === 'approve') { $courtController->approveClaim((int)$seg[2]); exit(); }
    // PUT  /courts/claims/:id/reject
    if ($_SERVER['REQUEST_METHOD'] === 'PUT'  && isset($seg[1]) && $seg[1] === 'claims' && isset($seg[2]) && isset($seg[3]) && $seg[3] === 'reject')  { $courtController->rejectClaim((int)$seg[2]); exit(); }
    // POST /courts/claim — must check before generic create
    if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($seg[1]) && $seg[1] === 'claim') { Auth::require(); $courtController->claim(); exit(); }
    if ($_SERVER['REQUEST_METHOD'] === 'POST') { Auth::requireOwner(); $courtController->create(); exit(); }
    // PUT /courts/:id/verify  (before generic update)
    if ($_SERVER['REQUEST_METHOD'] === 'PUT' && isset($seg[1]) && isset($seg[2]) && $seg[2] === 'verify') {
        Auth::requireAdmin(); $courtController->verify((int)$seg[1]); exit();
    }
    if ($_SERVER['REQUEST_METHOD'] === 'PUT'    && isset($seg[1])) { Auth::requireOwner(); $courtController->update((int)$seg[1]); exit(); }
    if ($_SERVER['REQUEST_METHOD'] === 'DELETE' && isset($seg[1])) { Auth::requireOwner(); $courtController->delete((int)$seg[1]); exit(); }
}

// Plan Routes
if (isset($seg[0]) && $seg[0] === 'plans') {
    require_once __DIR__ . '/src/Controllers/PlanController.php';
    $planController = new PlanController();

    if ($_SERVER['REQUEST_METHOD'] === 'GET') {
        $planController->index();
        exit();
    }

    if ($_SERVER['REQUEST_METHOD'] === 'POST') {
        Auth::requireOwner();
        $planController->create();
        exit();
    }

    if ($_SERVER['REQUEST_METHOD'] === 'DELETE' && isset($seg[1])) {
        Auth::requireOwner();
        $planController->delete((int)$seg[1]);
        exit();
    }
}

// Subscription Routes
if (isset($seg[0]) && $seg[0] === 'subscriptions') {
    require_once __DIR__ . '/src/Controllers/SubscriptionController.php';
    $subController = new SubscriptionController();

    if ($_SERVER['REQUEST_METHOD'] === 'GET' && isset($seg[1]) && $seg[1] === 'members') { Auth::requireOwner(); $subController->members(); exit(); }
    if ($_SERVER['REQUEST_METHOD'] === 'GET') { Auth::require(); $subController->index(); exit(); }
    if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($seg[1]) && $seg[1] === 'renew') { Auth::require(); $subController->renew(); exit(); }
    if ($_SERVER['REQUEST_METHOD'] === 'POST' && !isset($seg[1])) { Auth::require(); $subController->create(); exit(); }
    if ($_SERVER['REQUEST_METHOD'] === 'PUT' && isset($seg[1]) && isset($seg[2]) && $seg[2] === 'cancel') {
        Auth::require(); $subController->cancel((int)$seg[1]); exit();
    }
}

// In-app Notifications Routes — /notifications/list, /notifications/:id/read, /notifications/read-all
if (isset($seg[0]) && $seg[0] === 'notifications') {
    require_once __DIR__ . '/src/Controllers/NotificationController.php';
    $notifCtrl = new NotificationController();
    // GET /notifications/list
    if ($_SERVER['REQUEST_METHOD'] === 'GET' && isset($seg[1]) && $seg[1] === 'list') { Auth::require(); $notifCtrl->list(); exit(); }
    // PUT /notifications/read-all
    if ($_SERVER['REQUEST_METHOD'] === 'PUT' && isset($seg[1]) && $seg[1] === 'read-all') { Auth::require(); $notifCtrl->markAllRead(); exit(); }
    // PUT /notifications/:id/read
    if ($_SERVER['REQUEST_METHOD'] === 'PUT' && isset($seg[1]) && is_numeric($seg[1]) && isset($seg[2]) && $seg[2] === 'read') { Auth::require(); $notifCtrl->markRead((int)$seg[1]); exit(); }
}

// Notifications Route — GET /notifications (subscription expiry alerts, legacy)
if (isset($seg[0]) && $seg[0] === 'notifications' && $_SERVER['REQUEST_METHOD'] === 'GET') {
    $authUser = Auth::require();
    $user_id  = (int)$authUser['id']; // always from token
    $db   = Database::getConnection();
    $stmt = $db->prepare(
        "SELECT us.id, us.end_date, us.status, p.name AS plan_name, c.id AS court_id, c.name AS court_name
         FROM user_subscriptions us
         JOIN plans p  ON us.plan_id  = p.id
         JOIN courts c ON us.court_id = c.id
         WHERE us.user_id = ? AND us.status = 'active'
           AND us.end_date BETWEEN CURDATE() AND DATE_ADD(CURDATE(), INTERVAL 7 DAY)
         ORDER BY us.end_date ASC"
    );
    $stmt->execute([$user_id]);
    $expiring = $stmt->fetchAll(PDO::FETCH_ASSOC);
    echo json_encode(['expiring_soon' => $expiring, 'count' => count($expiring)]);
    exit();
}

// Booking Routes
if (isset($seg[0]) && $seg[0] === 'bookings') {
    require_once __DIR__ . '/src/Controllers/BookingController.php';
    $bookingController = new BookingController();

    // GET /bookings/busy-days?court_id=X&month=YYYY-MM  (before generic index)
    if ($_SERVER['REQUEST_METHOD'] === 'GET' && isset($seg[1]) && $seg[1] === 'busy-days') {
        $bookingController->busyDays(); exit();
    }
    // POST /bookings/recurring
    if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($seg[1]) && $seg[1] === 'recurring') {
        Auth::require(); $bookingController->createRecurring(); exit();
    }
    // GET /bookings/:id  — single booking detail (before generic index)
    if ($_SERVER['REQUEST_METHOD'] === 'GET' && isset($seg[1]) && is_numeric($seg[1])) {
        Auth::require(); $bookingController->show((int)$seg[1]); exit();
    }
    if ($_SERVER['REQUEST_METHOD'] === 'GET') { Auth::require(); $bookingController->index(); exit(); }
    if ($_SERVER['REQUEST_METHOD'] === 'POST') { Auth::require(); $bookingController->create(); exit(); }
    if ($_SERVER['REQUEST_METHOD'] === 'DELETE' && isset($seg[1])) {
        Auth::require(); $bookingController->cancel((int)$seg[1]); exit();
    }
}

// Earnings Routes
if (isset($seg[0]) && $seg[0] === 'earnings') {
    require_once __DIR__ . '/src/Controllers/EarningsController.php';
    $earningsController = new EarningsController();
    if ($_SERVER['REQUEST_METHOD'] === 'GET' && isset($seg[1]) && $seg[1] === 'ledger') {
        Auth::requireOwner(); $earningsController->ledger(); exit();
    }
    if ($_SERVER['REQUEST_METHOD'] === 'GET' && isset($seg[1]) && $seg[1] === 'venue') {
        Auth::requireOwner(); $earningsController->venue(); exit();
    }
    if ($_SERVER['REQUEST_METHOD'] === 'GET' && isset($seg[1]) && $seg[1] === 'export') {
        Auth::requireOwner(); $earningsController->export(); exit();
    }
    if ($_SERVER['REQUEST_METHOD'] === 'GET') { Auth::requireOwner(); $earningsController->index(); exit(); }
}

// Payouts Routes (admin records manual transfers)
if (isset($seg[0]) && $seg[0] === 'payouts') {
    require_once __DIR__ . '/src/Controllers/EarningsController.php';
    $earningsController = new EarningsController();
    if ($_SERVER['REQUEST_METHOD'] === 'POST') { Auth::requireAdmin(); $earningsController->createPayout(); exit(); }
}

// Review Routes
if (isset($seg[0]) && $seg[0] === 'reviews') {
    require_once __DIR__ . '/src/Controllers/ReviewController.php';
    $reviewController = new ReviewController();
    if ($_SERVER['REQUEST_METHOD'] === 'GET')  { $reviewController->index();  exit(); }
    if ($_SERVER['REQUEST_METHOD'] === 'POST') { Auth::require(); $reviewController->create(); exit(); }
    // PUT /reviews/:id/reply
    if ($_SERVER['REQUEST_METHOD'] === 'PUT' && isset($seg[1]) && isset($seg[2]) && $seg[2] === 'reply') {
        Auth::requireOwner(); $reviewController->reply((int)$seg[1]); exit();
    }
}

// Favorites Routes
if (isset($seg[0]) && $seg[0] === 'favorites') {
    require_once __DIR__ . '/src/Controllers/FavoriteController.php';
    $favController = new FavoriteController();
    if ($_SERVER['REQUEST_METHOD'] === 'GET')  { Auth::require(); $favController->index();  exit(); }
    if ($_SERVER['REQUEST_METHOD'] === 'POST') { Auth::require(); $favController->toggle(); exit(); }
}

// Posts Routes
if (isset($seg[0]) && $seg[0] === 'posts') {
    require_once __DIR__ . '/src/Controllers/PostController.php';
    $postController = new PostController();

    if ($_SERVER['REQUEST_METHOD'] === 'GET' && !isset($seg[1])) { $postController->index(); exit(); }
    if ($_SERVER['REQUEST_METHOD'] === 'GET' && isset($seg[1]) && is_numeric($seg[1])) { $postController->show((int)$seg[1]); exit(); }
    if ($_SERVER['REQUEST_METHOD'] === 'POST'  && !isset($seg[1])) { $postController->create(); exit(); }
    if ($_SERVER['REQUEST_METHOD'] === 'DELETE' && isset($seg[1])) { $postController->delete((int)$seg[1]); exit(); }
    if ($_SERVER['REQUEST_METHOD'] === 'POST'  && isset($seg[1]) && isset($seg[2]) && $seg[2] === 'like') {
        $postController->like((int)$seg[1]); exit();
    }
}

// Google Place Photo proxy — GET /place-photo?ref=places/xxx/photos/yyy
if (isset($seg[0]) && $seg[0] === 'place-photo') {
    $ref    = $_GET['ref'] ?? '';
    $apiKey = getenv('GOOGLE_PLACES_API_KEY') ?: '';
    if (!$ref || !$apiKey) { http_response_code(400); exit(); }

    $url = 'https://places.googleapis.com/v1/' . $ref . '/media?maxWidthPx=800&skipHttpRedirect=true&key=' . $apiKey;
    $ch  = curl_init($url);
    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_TIMEOUT        => 10,
        CURLOPT_SSL_VERIFYPEER => true,
        CURLOPT_USERAGENT      => 'KoCourt/1.0',
    ]);
    $resp     = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);

    if ($httpCode === 200 && $resp) {
        $data     = json_decode($resp, true);
        $photoUri = $data['photoUri'] ?? null;
        if ($photoUri) {
            // Cache header so browser doesn't re-fetch on every load
            header('Cache-Control: public, max-age=2592000'); // 30 days
            header('Location: ' . $photoUri, true, 302);
            exit();
        }
    }
    // Fallback: redirect to a generic sports image
    header('Location: https://images.unsplash.com/photo-1535131749006-b7f58c99034b?w=800&q=80', true, 302);
    exit();
}

// Debug: GET /nearby-places/test?lat=&lng= — tests MapmyIndia + Overpass connectivity
if (isset($seg[0], $seg[1]) && $seg[0] === 'nearby-places' && $seg[1] === 'test') {
    $lat       = (float)($_GET['lat'] ?? 12.9716);
    $lng       = (float)($_GET['lng'] ?? 77.5946);
    $clientId  = getenv('MAPMYINDIA_CLIENT_ID')     ?: '';
    $clientSec = getenv('MAPMYINDIA_CLIENT_SECRET') ?: '';
    $result    = ['mmi' => null, 'overpass' => null];

    if ($clientId && $clientSec) {
        $ch = curl_init('https://outpost.mapmyindia.com/api/security/oauth/token');
        curl_setopt_array($ch, [CURLOPT_RETURNTRANSFER=>true,CURLOPT_POST=>true,CURLOPT_POSTFIELDS=>http_build_query(['grant_type'=>'client_credentials','client_id'=>$clientId,'client_secret'=>$clientSec]),CURLOPT_TIMEOUT=>10]);
        $tokenResp = curl_exec($ch); $tokenCode = curl_getinfo($ch, CURLINFO_HTTP_CODE); curl_close($ch);
        $tokenData = json_decode($tokenResp, true);
        $token = $tokenData['access_token'] ?? null;
        if ($token) {
            $url = 'https://atlas.mapmyindia.com/api/places/nearby/json?keywords=' . urlencode('Badminton Court;Cricket Ground;Sports Complex;Gymnasium;Turf') . '&refLocation=' . $lat . ',' . $lng . '&radius=10000';
            $ch2 = curl_init($url);
            curl_setopt_array($ch2, [CURLOPT_RETURNTRANSFER=>true,CURLOPT_TIMEOUT=>10,CURLOPT_HTTPHEADER=>['Authorization: Bearer '.$token]]);
            $mmiResp = curl_exec($ch2); $mmiCode = curl_getinfo($ch2, CURLINFO_HTTP_CODE); curl_close($ch2);
            $mmiData = json_decode($mmiResp, true);
            $result['mmi'] = ['http_code'=>$mmiCode,'count'=>count($mmiData['suggestedLocations'] ?? []),'preview'=>array_slice($mmiData['suggestedLocations'] ?? [], 0, 5)];
        } else {
            $result['mmi'] = ['error'=>'Token fetch failed','http_code'=>$tokenCode,'raw'=>substr($tokenResp,0,200)];
        }
    } else {
        $result['mmi'] = ['error'=>'MAPMYINDIA credentials not set in .env'];
    }

    $query = '[out:json][timeout:15];(node["name"~"sports|court|ground|gym|badminton|cricket",i](around:10000,'.$lat.','.$lng.'););out center 5;';
    $ch3 = curl_init('https://overpass-api.de/api/interpreter');
    curl_setopt_array($ch3, [CURLOPT_RETURNTRANSFER=>true,CURLOPT_POST=>true,CURLOPT_POSTFIELDS=>'data='.urlencode($query),CURLOPT_TIMEOUT=>15,CURLOPT_USERAGENT=>'KoCourt/1.0']);
    $ovResp = curl_exec($ch3); $ovCode = curl_getinfo($ch3, CURLINFO_HTTP_CODE); curl_close($ch3);
    $ovData = json_decode($ovResp, true);
    $result['overpass'] = ['http_code'=>$ovCode,'count'=>count($ovData['elements'] ?? []),'preview'=>array_slice($ovData['elements'] ?? [], 0, 3)];

    echo json_encode($result, JSON_PRETTY_PRINT);
    exit();
}

// Ghost Listings — GET /nearby-places?lat=&lng=&user_id=
if (isset($seg[0]) && $seg[0] === 'nearby-places' && $_SERVER['REQUEST_METHOD'] === 'GET') {
    require_once __DIR__ . '/src/Controllers/PlacesController.php';
    (new PlacesController())->nearby();
    exit();
}

// Service Requests — POST /service-requests
if (isset($seg[0]) && $seg[0] === 'service-requests' && $_SERVER['REQUEST_METHOD'] === 'POST') {
    require_once __DIR__ . '/src/Controllers/PlacesController.php';
    (new PlacesController())->requestService();
    exit();
}

// Blocked Slots Routes
if (isset($seg[0]) && $seg[0] === 'blocked-slots') {
    require_once __DIR__ . '/src/Controllers/BlockController.php';
    $bc2 = new BlockController();
    if ($_SERVER['REQUEST_METHOD'] === 'GET')                      { $bc2->index();              exit(); }
    if ($_SERVER['REQUEST_METHOD'] === 'POST')                     { $bc2->create();             exit(); }
    if ($_SERVER['REQUEST_METHOD'] === 'DELETE' && isset($seg[1])) { $bc2->delete((int)$seg[1]); exit(); }
}

// Sub-Courts Routes
if (isset($seg[0]) && $seg[0] === 'sub-courts') {
    require_once __DIR__ . '/src/Controllers/SubCourtController.php';
    $scc = new SubCourtController();
    if ($_SERVER['REQUEST_METHOD'] === 'GET' && isset($seg[1]) && is_numeric($seg[1])) { $scc->show((int)$seg[1]); exit(); }
    if ($_SERVER['REQUEST_METHOD'] === 'GET')                      { $scc->index();              exit(); }
    if ($_SERVER['REQUEST_METHOD'] === 'POST')                     { $scc->create();             exit(); }
    if ($_SERVER['REQUEST_METHOD'] === 'PUT'    && isset($seg[1])) { $scc->update((int)$seg[1]); exit(); }
    if ($_SERVER['REQUEST_METHOD'] === 'DELETE' && isset($seg[1])) { $scc->delete((int)$seg[1]); exit(); }
}

// Pricing Rules Routes
if (isset($seg[0]) && $seg[0] === 'pricing-rules') {
    require_once __DIR__ . '/src/Controllers/PricingController.php';
    $prc = new PricingController();
    if ($_SERVER['REQUEST_METHOD'] === 'GET' && isset($seg[1]) && $seg[1] === 'calculate-day') { $prc->calculateDay(); exit(); }
    if ($_SERVER['REQUEST_METHOD'] === 'GET' && isset($seg[1]) && $seg[1] === 'calculate') { $prc->calculate(); exit(); }
    if ($_SERVER['REQUEST_METHOD'] === 'GET')                      { $prc->index();              exit(); }
    if ($_SERVER['REQUEST_METHOD'] === 'POST')                     { $prc->create();             exit(); }
    if ($_SERVER['REQUEST_METHOD'] === 'DELETE' && isset($seg[1])) { $prc->delete((int)$seg[1]); exit(); }
}

// Match Requests Routes
if (isset($seg[0]) && $seg[0] === 'match-requests') {
    require_once __DIR__ . '/src/Controllers/MatchController.php';
    $mrc = new MatchController();
    if ($_SERVER['REQUEST_METHOD'] === 'GET')                                                               { $mrc->index();             exit(); }
    if ($_SERVER['REQUEST_METHOD'] === 'POST' && !isset($seg[1]))                                           { $mrc->create();            exit(); }
    if ($_SERVER['REQUEST_METHOD'] === 'POST'   && isset($seg[1]) && isset($seg[2]) && $seg[2] === 'join')  { $mrc->join((int)$seg[1]);  exit(); }
    if ($_SERVER['REQUEST_METHOD'] === 'DELETE' && isset($seg[1]) && isset($seg[2]) && $seg[2] === 'leave') { $mrc->leave((int)$seg[1]); exit(); }
    if ($_SERVER['REQUEST_METHOD'] === 'DELETE' && isset($seg[1]))                                          { $mrc->cancel((int)$seg[1]);exit(); }
}

// Analytics Routes
if (isset($seg[0]) && $seg[0] === 'analytics') {
    require_once __DIR__ . '/src/Controllers/AnalyticsController.php';
    $anc = new AnalyticsController();
    if ($_SERVER['REQUEST_METHOD'] === 'GET') { $anc->index(); exit(); }
}

// Court Staff Routes
if (isset($seg[0]) && $seg[0] === 'court-staff') {
    require_once __DIR__ . '/src/Controllers/StaffController.php';
    $sc = new StaffController();
    if ($_SERVER['REQUEST_METHOD'] === 'GET' && isset($seg[1]) && $seg[1] === 'my-courts') { $sc->myCourts(); exit(); }
    if ($_SERVER['REQUEST_METHOD'] === 'GET')                                               { $sc->list();              exit(); }
    if ($_SERVER['REQUEST_METHOD'] === 'POST')                                              { $sc->add();               exit(); }
    if ($_SERVER['REQUEST_METHOD'] === 'DELETE' && isset($seg[1]))                          { $sc->remove((int)$seg[1]); exit(); }
}

// Admin Routes
if (isset($seg[0]) && $seg[0] === 'admin') {
    require_once __DIR__ . '/src/Controllers/PlacesController.php';
    $pc = new PlacesController();
    // GET /admin/demand?admin_id=X
    if (isset($seg[1]) && $seg[1] === 'demand' && $_SERVER['REQUEST_METHOD'] === 'GET') {
        $pc->adminDemand(); exit();
    }
    // GET /admin/prefetch-tamilnadu?admin_id=X
    if (isset($seg[1]) && $seg[1] === 'prefetch-tamilnadu' && $_SERVER['REQUEST_METHOD'] === 'GET') {
        $pc->prefetchTamilnadu(); exit();
    }
    // PUT /admin/places/:id/contact
    if (isset($seg[1]) && $seg[1] === 'places' && isset($seg[2]) && isset($seg[3]) && $seg[3] === 'contact' && $_SERVER['REQUEST_METHOD'] === 'PUT') {
        $pc->adminContact((int)$seg[2]); exit();
    }
    // GET /admin/users?admin_id=X
    if (isset($seg[1]) && $seg[1] === 'users' && $_SERVER['REQUEST_METHOD'] === 'GET') {
        $adminId = $_GET['admin_id'] ?? null;
        $db = Database::getConnection();
        $check = $db->prepare("SELECT role FROM users WHERE id = ?");
        $check->execute([$adminId]);
        $admin = $check->fetch(PDO::FETCH_ASSOC);
        if (!$admin || $admin['role'] !== 'admin') {
            http_response_code(403); echo json_encode(['message' => 'Forbidden']); exit();
        }
        $search = $_GET['search'] ?? '';
        if ($search) {
            $stmt = $db->prepare("SELECT id, name, phone, role, avatar_url, created_at FROM users WHERE name LIKE ? OR phone LIKE ? ORDER BY created_at DESC LIMIT 200");
            $stmt->execute(["%$search%", "%$search%"]);
        } else {
            $stmt = $db->prepare("SELECT id, name, phone, role, avatar_url, created_at FROM users ORDER BY created_at DESC LIMIT 200");
            $stmt->execute();
        }
        echo json_encode(['users' => $stmt->fetchAll(PDO::FETCH_ASSOC)]); exit();
    }
    http_response_code(404); echo json_encode(['message' => 'Admin endpoint not found']); exit();
}

// User Notifications — GET /user-notifications
if (isset($seg[0]) && $seg[0] === 'user-notifications') {
    $authUser = Auth::require();
    $uid      = (int)$authUser['id']; // always from token
    $db = Database::getConnection();
    // Ensure table exists
    $db->exec("
        CREATE TABLE IF NOT EXISTS user_notifications (
            id INT AUTO_INCREMENT PRIMARY KEY,
            user_id INT NOT NULL, type VARCHAR(50) NOT NULL,
            title VARCHAR(255) NOT NULL, body TEXT, court_id INT DEFAULT NULL,
            read_at DATETIME DEFAULT NULL, created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ");

    if ($_SERVER['REQUEST_METHOD'] === 'GET') {
        $stmt = $db->prepare(
            "SELECT n.*, c.name AS court_name FROM user_notifications n
             LEFT JOIN courts c ON c.id = n.court_id
             WHERE n.user_id = ? ORDER BY n.created_at DESC LIMIT 20"
        );
        $stmt->execute([$uid]);
        $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);
        echo json_encode(['notifications' => $rows]);
        exit();
    }

    // PUT /user-notifications/:id/read
    if ($_SERVER['REQUEST_METHOD'] === 'PUT' && isset($seg[1]) && isset($seg[2]) && $seg[2] === 'read') {
        // Only mark your own notifications as read
        $db->prepare("UPDATE user_notifications SET read_at = NOW() WHERE id = ? AND user_id = ?")->execute([(int)$seg[1], $uid]);
        echo json_encode(['success' => true]);
        exit();
    }
    exit();
}

// Tag Search — GET /tag-search?q=&type=users|courts|all
if (isset($seg[0]) && $seg[0] === 'tag-search' && $_SERVER['REQUEST_METHOD'] === 'GET') {
    $q    = '%' . trim($_GET['q'] ?? '') . '%';
    $type = $_GET['type'] ?? 'all';
    $db   = Database::getConnection();
    $out  = [];
    if ($type === 'users' || $type === 'all') {
        $s = $db->prepare("SELECT id, name, avatar_url, 'user' AS kind FROM users WHERE name LIKE ? LIMIT 6");
        $s->execute([$q]);
        $out = array_merge($out, $s->fetchAll(PDO::FETCH_ASSOC));
    }
    if ($type === 'courts' || $type === 'all') {
        $s = $db->prepare("SELECT id, name, type AS subtype, image_url, 'court' AS kind FROM courts WHERE name LIKE ? LIMIT 6");
        $s->execute([$q]);
        $out = array_merge($out, $s->fetchAll(PDO::FETCH_ASSOC));
    }
    echo json_encode(['results' => $out]);
    exit();
}

// ── Court Regulars  GET /courts/:id/regulars?exclude_user=X ──────────────────
if (isset($seg[0]) && $seg[0] === 'courts' && isset($seg[1]) && isset($seg[2]) && $seg[2] === 'regulars' && $_SERVER['REQUEST_METHOD'] === 'GET') {
    $court_id    = (int)$seg[1];
    $exclude_uid = (int)($_GET['exclude_user'] ?? 0);
    $db   = Database::getConnection();
    $stmt = $db->prepare(
        "SELECT u.id, u.name, u.phone, u.avatar_url, COUNT(b.id) AS booking_count
         FROM bookings b
         JOIN users u ON u.id = b.user_id
         WHERE b.court_id = ? AND b.status = 'confirmed'
           AND b.user_id != ?
           AND b.start_time >= DATE_SUB(NOW(), INTERVAL 90 DAY)
         GROUP BY u.id
         ORDER BY booking_count DESC
         LIMIT 12"
    );
    $stmt->execute([$court_id, $exclude_uid]);
    echo json_encode(['players' => $stmt->fetchAll(PDO::FETCH_ASSOC)]);
    exit();
}

// ── User search by phone  GET /users/search?phone=X ──────────────────────────
if (isset($seg[0]) && $seg[0] === 'users' && isset($seg[1]) && $seg[1] === 'search' && $_SERVER['REQUEST_METHOD'] === 'GET') {
    $phone = trim($_GET['phone'] ?? '');
    if (!$phone) { echo json_encode(['user' => null]); exit(); }
    $db   = Database::getConnection();
    $stmt = $db->prepare("SELECT id, name, phone, avatar_url FROM users WHERE phone = ? LIMIT 1");
    $stmt->execute([$phone]);
    $user = $stmt->fetch(PDO::FETCH_ASSOC) ?: null;
    echo json_encode(['user' => $user]);
    exit();
}

// ── Booking Players  POST/GET /booking-players ────────────────────────────────
if (isset($seg[0]) && $seg[0] === 'booking-players') {
    $db = Database::getConnection();
    // Auto-create table
    $db->exec("CREATE TABLE IF NOT EXISTS booking_players (
        id            INT AUTO_INCREMENT PRIMARY KEY,
        booking_id    INT NOT NULL,
        user_id       INT NOT NULL,
        invited_by    INT NOT NULL,
        created_at    DATETIME DEFAULT CURRENT_TIMESTAMP,
        UNIQUE KEY uniq_bp (booking_id, user_id),
        FOREIGN KEY (booking_id) REFERENCES bookings(id) ON DELETE CASCADE,
        FOREIGN KEY (user_id)    REFERENCES users(id)    ON DELETE CASCADE,
        FOREIGN KEY (invited_by) REFERENCES users(id)    ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");

    // GET /booking-players?booking_id=X
    if ($_SERVER['REQUEST_METHOD'] === 'GET') {
        Auth::require();
        $bid  = (int)($_GET['booking_id'] ?? 0);
        $stmt = $db->prepare(
            "SELECT u.id, u.name, u.phone, u.avatar_url
             FROM booking_players bp JOIN users u ON u.id = bp.user_id
             WHERE bp.booking_id = ?"
        );
        $stmt->execute([$bid]);
        echo json_encode(['players' => $stmt->fetchAll(PDO::FETCH_ASSOC)]);
        exit();
    }

    // POST /booking-players  { booking_id, user_ids:[] }
    if ($_SERVER['REQUEST_METHOD'] === 'POST') {
        $authUser   = Auth::require();
        $invited_by = (int)$authUser['id']; // always from token
        $body       = json_decode(file_get_contents('php://input'), true) ?? [];
        $booking_id = (int)($body['booking_id'] ?? 0);
        $user_ids   = array_filter(array_map('intval', $body['user_ids'] ?? []));

        if (!$booking_id || empty($user_ids)) {
            http_response_code(400); echo json_encode(['message' => 'booking_id and user_ids required']); exit();
        }

        // Fetch booking + court info for notification body
        $bStmt = $db->prepare(
            "SELECT b.start_time, c.name AS court_name, c.id AS court_id, u.name AS inviter_name
             FROM bookings b
             JOIN courts c ON c.id = b.court_id
             JOIN users  u ON u.id = ?
             WHERE b.id = ? LIMIT 1"
        );
        $bStmt->execute([$invited_by, $booking_id]);
        $info = $bStmt->fetch(PDO::FETCH_ASSOC);
        if (!$info) { http_response_code(404); echo json_encode(['message' => 'Booking not found']); exit(); }

        $dt    = new DateTime($info['start_time']);
        $date  = $dt->format('D, d M');
        $time  = $dt->format('h:i A');
        $title = $info['inviter_name'] . ' added you to a game!';
        $body_text = 'Join the session at ' . $info['court_name'] . ' on ' . $date . ' at ' . $time;

        $ins  = $db->prepare("INSERT IGNORE INTO booking_players (booking_id, user_id, invited_by) VALUES (?,?,?)");
        $notif = $db->prepare(
            "INSERT INTO user_notifications (user_id, type, title, body, court_id) VALUES (?,?,?,?,?)"
        );

        $added = 0;
        foreach ($user_ids as $uid) {
            if ($uid === $invited_by) continue;   // don't add yourself
            $ins->execute([$booking_id, $uid, $invited_by]);
            if ($ins->rowCount()) {
                $notif->execute([$uid, 'booking_invite', $title, $body_text, $info['court_id']]);
                $added++;
            }
        }
        echo json_encode(['added' => $added]);
        exit();
    }
    exit();
}

// Court Photos Routes
if (isset($seg[0]) && $seg[0] === 'court-photos') {
    require_once __DIR__ . '/src/Controllers/CourtPhotoController.php';
    $photoCtrl = new CourtPhotoController();
    if ($_SERVER['REQUEST_METHOD'] === 'GET')    { $photoCtrl->index();           exit(); }
    if ($_SERVER['REQUEST_METHOD'] === 'POST')   { $photoCtrl->create();          exit(); }
    if ($_SERVER['REQUEST_METHOD'] === 'DELETE' && isset($seg[1])) { $photoCtrl->delete((int)$seg[1]); exit(); }
}

// Messages Routes
if (isset($seg[0]) && $seg[0] === 'messages') {
    require_once __DIR__ . '/src/Controllers/MessageController.php';
    $msgCtrl = new MessageController();
    if ($_SERVER['REQUEST_METHOD'] === 'GET' && isset($seg[1]) && $seg[1] === 'threads')      { Auth::require(); $msgCtrl->threads();     exit(); }
    if ($_SERVER['REQUEST_METHOD'] === 'GET' && isset($seg[1]) && $seg[1] === 'unread-count') { Auth::require(); $msgCtrl->unreadCount(); exit(); }
    if ($_SERVER['REQUEST_METHOD'] === 'GET')  { Auth::require(); $msgCtrl->index();  exit(); }
    if ($_SERVER['REQUEST_METHOD'] === 'POST') { Auth::require(); $msgCtrl->create(); exit(); }
}

// Waitlist Routes
if (isset($seg[0]) && $seg[0] === 'waitlist') {
    require_once __DIR__ . '/src/Controllers/WaitlistController.php';
    $wlCtrl = new WaitlistController();
    if ($_SERVER['REQUEST_METHOD'] === 'GET')                      { Auth::require(); $wlCtrl->index();           exit(); }
    if ($_SERVER['REQUEST_METHOD'] === 'POST')                     { Auth::require(); $wlCtrl->create();          exit(); }
    if ($_SERVER['REQUEST_METHOD'] === 'DELETE' && isset($seg[1])) { Auth::require(); $wlCtrl->delete((int)$seg[1]); exit(); }
}

echo json_encode(["message" => "Welcome to Playbook API"]);
