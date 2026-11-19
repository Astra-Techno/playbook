<?php

/** Find a KoCourt account from a phone typed at the venue desk. */
class AccountLookup
{
    /**
     * Indian mobile as 10 digits. Strips spaces, +91, and a leading 0.
     * Empty when fewer than 10 digits remain.
     */
    public static function normalize(string $phone): string
    {
        $digits = preg_replace('/\D+/', '', $phone) ?? '';
        if (strlen($digits) >= 12 && str_starts_with($digits, '91')) {
            $digits = substr($digits, -10);
        }
        if (strlen($digits) === 11 && str_starts_with($digits, '0')) {
            $digits = substr($digits, 1);
        }
        if (strlen($digits) > 10) {
            $digits = substr($digits, -10);
        }
        if (strlen($digits) !== 10) {
            return '';
        }
        return $digits;
    }

    /**
     * Values compared with users.phone. Empty when the desk entry has no 10-digit mobile.
     *
     * @return list<string>
     */
    public static function keys(string $phone): array
    {
        $last = self::normalize($phone);
        if ($last === '') {
            return [];
        }
        $variants = [
            trim($phone),
            $last,
            '0' . $last,
            '91' . $last,
            '+91' . $last,
            '+91 ' . $last,
            '91-' . $last,
        ];
        $unique = [];
        foreach ($variants as $value) {
            if ($value === '') {
                continue;
            }
            $unique[$value] = $value;
        }
        return array_values($unique);
    }

    /** Digits-only form of a stored phone for RIGHT(..., 10) style matching. */
    private static function digitSql(string $column): string
    {
        return "REPLACE(REPLACE(REPLACE(REPLACE(REPLACE($column, '+', ''), ' ', ''), '-', ''), '(', ''), ')', '')";
    }

    public static function byPhone(PDO $db, string $phone): ?array
    {
        $last = self::normalize($phone);
        $keys = self::keys($phone);
        if ($last === '' || $keys === []) {
            return null;
        }

        $placeholders = implode(', ', array_fill(0, count($keys), '?'));
        $digits = self::digitSql('phone');
        $stmt = $db->prepare(
            "SELECT id, name, phone, avatar_url FROM users
             WHERE phone IN ($placeholders)
                OR RIGHT($digits, 10) = ?
                OR RIGHT(phone, 10) = ?
             LIMIT 1"
        );
        $params = $keys;
        $params[] = $last;
        $params[] = $last;
        $stmt->execute($params);
        $row = $stmt->fetch(PDO::FETCH_ASSOC);
        return $row ?: null;
    }
}
