<?php

require_once __DIR__ . '/../Models/User.php';
require_once __DIR__ . '/../../config/msg91.php';

class AuthController {

    // ── Private: send OTP via MSG91 (returns true on success) ─────────────────
    private function formatPhone(string $phone): string {
        $clean = preg_replace('/\D/', '', $phone);
        // If it's 10 digits, prepend 91. If it's already 12 digits starting with 91, keep it.
        if (strlen($clean) === 10) return '91' . $clean;
        return $clean;
    }

    private function sendViaMSG91(string $phone): bool {
        $mobile = $this->formatPhone($phone);
        $ch = curl_init(MSG91_BASE_URL . '/otp');
        curl_setopt_array($ch, [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_POST           => true,
            CURLOPT_POSTFIELDS     => json_encode([
                'template_id' => MSG91_TEMPLATE_ID,
                'mobile'      => $mobile,
                'otp_length'  => 4,
            ]),
            CURLOPT_HTTPHEADER     => [
                'authkey: '    . MSG91_AUTH_KEY,
                'Content-Type: application/json',
                'Accept: application/json',
            ],
            CURLOPT_SSL_VERIFYPEER => true,
            CURLOPT_TIMEOUT        => 10,
        ]);
        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);
        $result = json_decode($response, true);
        return $httpCode === 200 && ($result['type'] ?? '') === 'success';
    }

    // ── Private: verify OTP via MSG91 ─────────────────────────────────────────
    private function verifyViaMSG91(string $phone, string $otp): bool {
        $mobile = $this->formatPhone($phone);
        $url = MSG91_BASE_URL . '/otp/verify?mobile=' . urlencode($mobile) . '&otp=' . urlencode($otp);
        $ch = curl_init($url);
        curl_setopt_array($ch, [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_HTTPHEADER     => [
                'authkey: ' . MSG91_AUTH_KEY,
                'Accept: application/json',
            ],
            CURLOPT_SSL_VERIFYPEER => true,
            CURLOPT_TIMEOUT        => 10,
        ]);
        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);
        $result = json_decode($response, true);
        return $httpCode === 200 && ($result['type'] ?? '') === 'success';
    }
    
    // POST /api/auth/send-otp { "phone": "9876543210" }
    public function sendOtp() {
        $data = json_decode(file_get_contents("php://input"));
        if (empty($data->phone)) {
            http_response_code(400);
            echo json_encode(["message" => "Phone number required"]);
            return;
        }

        // Dev/demo mode — no MSG91 keys configured
        if (!MSG91_AUTH_KEY || !MSG91_TEMPLATE_ID) {
            http_response_code(200);
            echo json_encode(["message" => "OTP sent", "demo" => true]);
            return;
        }

        if ($this->sendViaMSG91($data->phone)) {
            http_response_code(200);
            echo json_encode(["message" => "OTP sent"]);
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

        // OTP verification — MSG91 if configured, else demo mode (accept "1234")
        if (MSG91_AUTH_KEY && MSG91_TEMPLATE_ID) {
            if (!$this->verifyViaMSG91($data->phone, $data->otp)) {
                http_response_code(401);
                echo json_encode(["message" => "Invalid or expired OTP"]);
                return;
            }
        } else {
            // Demo mode fallback
            if ($data->otp !== '1234') {
                http_response_code(401);
                echo json_encode(["message" => "Invalid OTP (demo: use 1234)"]);
                return;
            }
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

    // PUT /api/auth/profile  { user_id, name?, avatar_url?, bio?, skill_level?, sport_preferences? }
    public function updateProfile() {
        $data    = json_decode(file_get_contents("php://input"));
        $user_id = (int)($data->user_id ?? 0);
        if (!$user_id) { http_response_code(400); echo json_encode(['message' => 'user_id required']); return; }
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

    private function sendTokenResponse($user) {
        $token = bin2hex(random_bytes(16));
        $db    = Database::getConnection();
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
