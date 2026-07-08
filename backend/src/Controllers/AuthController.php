<?php

require_once __DIR__ . '/../Models/User.php';
require_once __DIR__ . '/../../config/ping4sms.php';

class AuthController {

    // ── Private helpers ────────────────────────────────────────────────────────

    /** Strip non-digits, return 10-digit number (drop leading 91 if present) */
    private function normalizePhone(string $phone): string {
        $clean = preg_replace('/\D/', '', $phone);
        if (strlen($clean) === 12 && substr($clean, 0, 2) === '91') {
            return substr($clean, 2);
        }
        return $clean;
    }

    /** Generate a 4-digit OTP, store in otp_tokens, send via ping4sms.
     *  Returns true on success, false on SMS failure. Demo mode skips sending. */
    private function generateAndSendOtp(string $phone): bool {
        $otp     = str_pad((string)random_int(1000, 9999), 4, '0', STR_PAD_LEFT);
        $expires = date('Y-m-d H:i:s', time() + 15 * 60); // 15 minutes

        $db = Database::getConnection();
        // Delete any old tokens for this phone, then insert new one
        $db->prepare("DELETE FROM otp_tokens WHERE phone = ?")->execute([$phone]);
        $db->prepare("INSERT INTO otp_tokens (phone, otp, expires_at) VALUES (?,?,?)")
           ->execute([$phone, $otp, $expires]);

        // Demo mode — no ping4sms key configured
        if (!PING4SMS_KEY || !PING4SMS_TEMPLATE_ID) {
            return true; // OTP stored as 4-digit random; caller returns demo=true
        }

        $number  = $this->normalizePhone($phone);
        $message = 'Dear User, your OTP to login to KoCourt is ' . $otp
                 . '. This OTP is valid for 15 minutes. Do not share this OTP. - KoCourt';
        $url = PING4SMS_BASE_URL . '?' . http_build_query([
            'key'        => PING4SMS_KEY,
            'route'      => PING4SMS_ROUTE,
            'sender'     => PING4SMS_SENDER,
            'number'     => $number,
            'sms'        => $message,
            'templateid' => PING4SMS_TEMPLATE_ID,
        ]);

        $ch = curl_init($url);
        curl_setopt_array($ch, [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_SSL_VERIFYPEER => true,
            CURLOPT_TIMEOUT        => 10,
        ]);
        curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);

        return $httpCode === 200;
    }

    /** Verify OTP from otp_tokens table. Deletes the token on success. */
    private function verifyOtpFromDB(string $phone, string $otp): bool {
        $db   = Database::getConnection();
        $stmt = $db->prepare(
            "SELECT id FROM otp_tokens WHERE phone = ? AND otp = ? AND expires_at > NOW() LIMIT 1"
        );
        $stmt->execute([$phone, $otp]);
        $row = $stmt->fetch();
        if (!$row) return false;
        $db->prepare("DELETE FROM otp_tokens WHERE phone = ?")->execute([$phone]);
        return true;
    }

    // POST /api/auth/send-otp { "phone": "9876543210" }
    public function sendOtp() {
        $data = json_decode(file_get_contents("php://input"));
        if (empty($data->phone)) {
            http_response_code(400);
            echo json_encode(["message" => "Phone number required"]);
            return;
        }

        $demo = !PING4SMS_KEY || !PING4SMS_TEMPLATE_ID;
        $sent = $this->generateAndSendOtp($data->phone);

        if ($sent) {
            http_response_code(200);
            echo json_encode(array_filter(["message" => "OTP sent", "demo" => $demo ?: null]));
        } else {
            http_response_code(502);
            echo json_encode(["message" => "Failed to send OTP. Please try again."]);
        }
    }

    // Check if phone exists - to decide whether to show "Enter Name" fields
    // POST /api/auth/check-phone { "phone": "123" }
    public function checkPhone() {
        $data = json_decode(file_get_contents("php://input"));
        
        if(!empty($data->phone)) {
            $user = new User();
            $user->phone = $data->phone;
            $exists = $user->phoneExists();
            
            http_response_code(200);
            echo json_encode(["exists" => $exists]);
        } else {
            http_response_code(400);
            echo json_encode(["message" => "Phone number required"]);
        }
    }

    // Verify OTP and Login/Register
    // POST /api/auth/verify-otp { "phone": "123", "otp": "1234", "name": "Optional", "role": "Optional" }
    public function verifyOtp() {
        $data = json_decode(file_get_contents("php://input"));

        if(empty($data->phone) || empty($data->otp)) {
            http_response_code(400);
            echo json_encode(["message" => "Phone and OTP required"]);
            return;
        }

        // OTP verification — check otp_tokens table (set by send-otp)
        // Demo fallback: if no SMS key configured, also accept "1234"
        $demo = !PING4SMS_KEY || !PING4SMS_TEMPLATE_ID;
        $valid = $this->verifyOtpFromDB($data->phone, $data->otp);
        if (!$valid && $demo && $data->otp === '1234') $valid = true;
        if (!$valid) {
            http_response_code(401);
            echo json_encode(["message" => "Invalid or expired OTP"]);
            return;
        }

        $user = new User();
        $user->phone = $data->phone;

        if($user->phoneExists()) {
            // Login existing user
            $this->sendTokenResponse($user);
        } else {
            // Register new user
            if(empty($data->name)) {
                http_response_code(404);
                echo json_encode(["new_user" => true, "message" => "New user — name required."]);
                return;
            }

            $user->name = $data->name;
            $user->role = 'player'; // all new users are player by default

            try {
                if($user->create()) {
                    // Fetch the new user's ID and data
                    $user->phoneExists();
                    $this->sendTokenResponse($user);
                } else {
                    http_response_code(503);
                    echo json_encode(["message" => "Unable to create user."]);
                }
            } catch (Exception $e) {
                http_response_code(503);
                echo json_encode(["message" => "Unable to create user: " . $e->getMessage()]);
            }
        }
    }

    // PUT /api/auth/profile  { name?, avatar_url?, bio?, skill_level?, sport_preferences? }
    public function updateProfile() {
        $authUser = Auth::require();
        $user_id  = (int)$authUser['id'];
        $data     = json_decode(file_get_contents("php://input"));
        $db     = Database::getConnection();
        $fields = []; $vals = [];
        if (!empty($data->name))       { $fields[] = "name=?";               $vals[] = trim($data->name); }
        if (!empty($data->avatar_url)) { $fields[] = "avatar_url=?";         $vals[] = trim($data->avatar_url); }
        if (isset($data->bio))         { $fields[] = "bio=?";                $vals[] = htmlspecialchars(strip_tags(trim($data->bio))); }
        if (isset($data->skill_level)) { $fields[] = "skill_level=?";        $vals[] = $data->skill_level; }
        if (isset($data->sport_preferences)) { $fields[] = "sport_preferences=?"; $vals[] = json_encode($data->sport_preferences); }
        if ($fields) {
            $vals[] = $user_id;
            $db->prepare("UPDATE users SET " . implode(', ', $fields) . " WHERE id=?")->execute($vals);
        }
        $uStmt = $db->prepare("SELECT id, name, phone, role, avatar_url, bio, skill_level, sport_preferences FROM users WHERE id=?");
        $uStmt->execute([$user_id]);
        $user = $uStmt->fetch(PDO::FETCH_ASSOC);
        if ($user && $user['sport_preferences']) $user['sport_preferences'] = json_decode($user['sport_preferences']);
        http_response_code(200);
        echo json_encode(['message' => 'Profile updated', 'user' => $user]);
    }

    // GET /api/auth/profile
    public function getProfile() {
        $authUser = Auth::require();
        $user_id  = (int)$authUser['id'];
        $db    = Database::getConnection();
        $uStmt = $db->prepare("SELECT id, name, phone, role, avatar_url, bio, skill_level, sport_preferences FROM users WHERE id=?");
        $uStmt->execute([$user_id]);
        $user = $uStmt->fetch(PDO::FETCH_ASSOC);
        if (!$user) { http_response_code(404); echo json_encode(['message' => 'User not found']); return; }
        if ($user['sport_preferences']) $user['sport_preferences'] = json_decode($user['sport_preferences']);
        echo json_encode(['user' => $user]);
    }

    // POST /auth/fcm-token  { token: "..." }
    public function saveFcmToken() {
        $authUser = Auth::require();
        $data     = json_decode(file_get_contents("php://input"));
        $token    = trim($data->token ?? '');
        if (!$token) { http_response_code(400); echo json_encode(['message' => 'token required']); return; }
        $db = Database::getConnection();
        $db->prepare("UPDATE users SET fcm_token = ? WHERE id = ?")->execute([$token, (int)$authUser['id']]);
        echo json_encode(['success' => true]);
    }

    private function sendTokenResponse($user) {
        $token = bin2hex(random_bytes(32)); // 64-char hex token
        $db    = Database::getConnection();
        // Persist token so backend can validate it on every request
        $db->prepare("UPDATE users SET auth_token = ? WHERE phone = ?")->execute([$token, $user->phone]);
        $stmt  = $db->prepare("SELECT id, name, phone, role, avatar_url, bio, skill_level, sport_preferences FROM users WHERE phone = ?");
        $stmt->execute([$user->phone]);
        $row = $stmt->fetch(\PDO::FETCH_ASSOC) ?: [];
        if ($row && $row['sport_preferences']) $row['sport_preferences'] = json_decode($row['sport_preferences']);
        http_response_code(200);
        echo json_encode([
            "message" => "Success",
            "token"   => $token,
            "user"    => $row,
        ]);
    }
}
