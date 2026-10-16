<?php

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../config/cashfree.php';

class VendorController {

    /**
     * GET /api/vendor/profile — get current user's vendor profile (bank/UPI details)
     */
    public function profile(): void {
        $authUser = Auth::require();
        $userId   = (int)$authUser['id'];
        $db       = Database::getConnection();

        $stmt = $db->prepare("SELECT * FROM vendor_profiles WHERE user_id = ?");
        $stmt->execute([$userId]);
        $profile = $stmt->fetch(PDO::FETCH_ASSOC);

        // Mask sensitive fields
        if ($profile) {
            if ($profile['account_number']) {
                $profile['account_number_masked'] = str_repeat('*', max(0, strlen($profile['account_number']) - 4))
                    . substr($profile['account_number'], -4);
                unset($profile['account_number']);
            }
            if ($profile['pan_number']) {
                $profile['pan_masked'] = substr($profile['pan_number'], 0, 2)
                    . str_repeat('*', max(0, strlen($profile['pan_number']) - 4))
                    . substr($profile['pan_number'], -2);
                unset($profile['pan_number']);
            }
        }

        // Get commission
        $commStmt = $db->prepare("SELECT `value` FROM config WHERE `key` = 'platform_commission_pct'");
        $commStmt->execute();
        $commission = (float)($commStmt->fetchColumn() ?: 10);

        echo json_encode([
            'profile'    => $profile,
            'commission' => $commission,
        ]);
    }

    /**
     * POST /api/vendor/profile — save bank/UPI details and register as Cashfree vendor
     * Body: { account_type: 'bank_account'|'upi', account_holder, account_number?, ifsc_code?, upi_vpa?, pan_number? }
     */
    public function save(): void {
        $authUser = Auth::require();
        $userId   = (int)$authUser['id'];
        $data     = json_decode(file_get_contents('php://input'), true) ?: [];
        $db       = Database::getConnection();

        $accountType = ($data['account_type'] ?? 'bank_account') === 'upi' ? 'upi' : 'bank_account';

        // Validate
        if ($accountType === 'bank_account') {
            if (empty($data['account_holder']) || empty($data['account_number']) || empty($data['ifsc_code'])) {
                http_response_code(400);
                echo json_encode(['message' => 'Account holder, account number, and IFSC code are required']);
                return;
            }
        } else {
            if (empty($data['upi_vpa'])) {
                http_response_code(400);
                echo json_encode(['message' => 'UPI VPA is required']);
                return;
            }
        }

        // Upsert vendor profile locally
        $existing = $db->prepare("SELECT id, cf_vendor_id FROM vendor_profiles WHERE user_id = ?");
        $existing->execute([$userId]);
        $row = $existing->fetch(PDO::FETCH_ASSOC);

        if ($row) {
            $db->prepare("UPDATE vendor_profiles SET
                account_type = ?, account_holder = ?, account_number = ?,
                ifsc_code = ?, upi_vpa = ?, pan_number = ?
                WHERE user_id = ?")
                ->execute([
                    $accountType,
                    $data['account_holder'] ?? null,
                    $data['account_number'] ?? null,
                    $data['ifsc_code'] ?? null,
                    $data['upi_vpa'] ?? null,
                    $data['pan_number'] ?? null,
                    $userId,
                ]);
        } else {
            $db->prepare("INSERT INTO vendor_profiles
                (user_id, account_type, account_holder, account_number, ifsc_code, upi_vpa, pan_number)
                VALUES (?, ?, ?, ?, ?, ?, ?)")
                ->execute([
                    $userId,
                    $accountType,
                    $data['account_holder'] ?? null,
                    $data['account_number'] ?? null,
                    $data['ifsc_code'] ?? null,
                    $data['upi_vpa'] ?? null,
                    $data['pan_number'] ?? null,
                ]);
        }

        // Register/update on Cashfree Easy Split
        $cfResult = $this->syncWithCashfree($db, $userId, $authUser);

        echo json_encode([
            'message'   => 'Payout details saved',
            'cf_status' => $cfResult['status'] ?? 'pending',
            'cf_error'  => $cfResult['error'] ?? null,
        ]);
    }

    /**
     * Register or update vendor on Cashfree Easy Split.
     */
    private function syncWithCashfree(PDO $db, int $userId, array $authUser): array {
        // Skip in demo mode
        if (!CASHFREE_APP_ID || CASHFREE_APP_ID === 'your_cashfree_app_id') {
            $db->prepare("UPDATE vendor_profiles SET cf_vendor_status = 'active', cf_vendor_id = ? WHERE user_id = ?")
               ->execute(['demo_vendor_' . $userId, $userId]);
            return ['status' => 'active'];
        }

        $stmt = $db->prepare("SELECT * FROM vendor_profiles WHERE user_id = ?");
        $stmt->execute([$userId]);
        $profile = $stmt->fetch(PDO::FETCH_ASSOC);
        if (!$profile) return ['status' => 'error', 'error' => 'No profile found'];

        $vendorId = $profile['cf_vendor_id'] ?: 'kocourt_vendor_' . $userId;
        $phone    = preg_replace('/\D/', '', $authUser['phone'] ?? '');
        if (strlen($phone) > 10) $phone = substr($phone, -10);

        $body = [
            'vendor_id'   => $vendorId,
            'name'        => $profile['account_holder'] ?: ($authUser['name'] ?? 'Vendor'),
            'email'       => $authUser['email'] ?? ($vendorId . '@kocourt.com'),
            'phone'       => $phone ?: '9999999999',
            'verify_account' => true,
            'dashboard_access' => false,
            'schedule_option'  => 1,
        ];

        // Bank or UPI
        if ($profile['account_type'] === 'bank_account' && $profile['account_number']) {
            $body['bank'] = [
                'account_number' => $profile['account_number'],
                'account_holder' => $profile['account_holder'],
                'ifsc'           => $profile['ifsc_code'],
            ];
        } elseif ($profile['upi_vpa']) {
            $body['upi'] = [
                'vpa'            => $profile['upi_vpa'],
                'account_holder' => $profile['account_holder'],
            ];
        }

        if ($profile['pan_number']) {
            $body['kyc_details'] = ['pan' => strtoupper($profile['pan_number'])];
        }

        // Create or update vendor
        $isUpdate = !empty($profile['cf_vendor_id']);
        $result   = $this->cfRequest(
            $isUpdate ? 'PATCH' : 'POST',
            '/easy-split/vendors' . ($isUpdate ? '/' . $vendorId : ''),
            $body
        );

        if ($result['code'] >= 200 && $result['code'] < 300) {
            $status = $result['data']['status'] ?? 'ACTIVE';
            $cfStatus = strtolower($status) === 'active' ? 'active' : 'pending';
            $db->prepare("UPDATE vendor_profiles SET cf_vendor_id = ?, cf_vendor_status = ? WHERE user_id = ?")
               ->execute([$vendorId, $cfStatus, $userId]);
            return ['status' => $cfStatus];
        }

        return [
            'status' => 'error',
            'error'  => $result['data']['message'] ?? ('HTTP ' . $result['code']),
        ];
    }

    /** Cashfree API helper */
    private function cfRequest(string $method, string $endpoint, array $body = []): array {
        $url = CASHFREE_BASE_URL . $endpoint;
        $ch  = curl_init($url);

        $headers = [
            'x-client-id: '     . CASHFREE_APP_ID,
            'x-client-secret: ' . CASHFREE_SECRET_KEY,
            'x-api-version: '   . CASHFREE_API_VERSION,
            'Content-Type: application/json',
            'Accept: application/json',
        ];

        curl_setopt_array($ch, [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_HTTPHEADER     => $headers,
            CURLOPT_SSL_VERIFYPEER => true,
            CURLOPT_TIMEOUT        => 15,
            CURLOPT_CUSTOMREQUEST  => $method,
        ]);

        if (in_array($method, ['POST', 'PATCH', 'PUT'])) {
            curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($body));
        }

        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);

        return ['code' => $httpCode, 'data' => json_decode($response, true) ?: []];
    }
}
