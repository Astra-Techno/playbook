<?php

/** Find a KoCourt account from a phone typed at the venue desk. */
class AccountLookup
{
    /** Values compared with users.phone. Empty when the desk entry has no digits. */
    public static function keys(string $phone): array
    {
        $digits = preg_replace('/\D+/', '', $phone) ?? '';
        if ($digits === '') {
            return [];
        }
        $last = strlen($digits) > 10 ? substr($digits, -10) : $digits;
        return [trim($phone), $digits, '+91' . $last, $last];
    }

    public static function byPhone(PDO $db, string $phone): ?array
    {
        $keys = self::keys($phone);
        if ($keys === []) {
            return null;
        }
        $stmt = $db->prepare(
            "SELECT id, name, phone, avatar_url FROM users
             WHERE phone = ? OR phone = ? OR phone = ?
                OR RIGHT(REPLACE(REPLACE(REPLACE(phone, '+', ''), ' ', ''), '-', ''), 10) = ?
             LIMIT 1"
        );
        $stmt->execute($keys);
        $row = $stmt->fetch(PDO::FETCH_ASSOC);
        return $row ?: null;
    }
}
