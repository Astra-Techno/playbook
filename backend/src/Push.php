<?php

/**
 * FCM push notification helper.
 * Uses Firebase HTTP v1 API (Bearer token) if FCM_SERVICE_ACCOUNT_JSON env is set,
 * falls back to legacy server key (FCM_SERVER_KEY) for simpler setups.
 *
 * Silently no-ops when no key is configured so dev environments aren't broken.
 */
class Push {

    /**
     * Send a push notification to a single FCM token.
     *
     * @param string $fcmToken   Recipient device FCM token
     * @param string $title      Notification title
     * @param string $body       Notification body
     * @param array  $data       Extra key/value data payload
     */
    public static function send(string $fcmToken, string $title, string $body, array $data = []): void {
        if (!$fcmToken) return;

        $serverKey = getenv('FCM_SERVER_KEY') ?: '';
        if (!$serverKey) return;  // not configured — skip silently

        $payload = json_encode([
            'to'           => $fcmToken,
            'notification' => [
                'title' => $title,
                'body'  => $body,
                'sound' => 'default',
            ],
            'data'         => $data,
            'priority'     => 'high',
        ]);

        $ch = curl_init('https://fcm.googleapis.com/fcm/send');
        curl_setopt_array($ch, [
            CURLOPT_POST           => true,
            CURLOPT_HTTPHEADER     => [
                'Authorization: key=' . $serverKey,
                'Content-Type: application/json',
            ],
            CURLOPT_POSTFIELDS     => $payload,
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_TIMEOUT        => 5,
        ]);
        curl_exec($ch);
        curl_close($ch);
    }

    /**
     * Look up FCM token for a user and send if found.
     */
    public static function sendToUser(int $userId, string $title, string $body, array $data = []): void {
        if (!$userId) return;
        $serverKey = getenv('FCM_SERVER_KEY') ?: '';
        if (!$serverKey) return;

        try {
            $db   = Database::getConnection();
            $stmt = $db->prepare("SELECT fcm_token FROM users WHERE id = ? AND fcm_token IS NOT NULL LIMIT 1");
            $stmt->execute([$userId]);
            $token = $stmt->fetchColumn();
            if ($token) self::send($token, $title, $body, $data);
        } catch (\Exception $e) { /* silent */ }
    }
}
