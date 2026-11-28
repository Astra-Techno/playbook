<?php

require_once __DIR__ . '/TournamentCheckIn.php';

/**
 * Door check-in for members (gym, pool, any membership plan). The member's pass shows
 * "KOCOURT-MEMBER:<subscription id>:<code>", where code is a random 8-character code stored
 * on the subscription. Each scan records one visit per member per day.
 */
final class MemberCheckIn
{
    public const PREFIX = 'KOCOURT-MEMBER';

    public static function payload(int $subscriptionId, string $code): string
    {
        return self::PREFIX . ':' . $subscriptionId . ':' . $code;
    }

    /** @return array{id:int,code:string}|null */
    public static function parse(string $payload): ?array
    {
        $parts = explode(':', trim($payload));
        if (count($parts) !== 3 || $parts[0] !== self::PREFIX || !ctype_digit($parts[1]) || (int)$parts[1] <= 0) {
            return null;
        }
        $code = TournamentCheckIn::codeValue($parts[2]);
        return $code === false ? null : ['id' => (int)$parts[1], 'code' => $code];
    }

    /** Stored code matches the scanned one, in constant time. */
    public static function matches(?string $stored, string $scanned): bool
    {
        return $stored !== null && $stored !== '' && hash_equals($stored, $scanned);
    }

    /**
     * Whether a member may come in today. Dates are 'Y-m-d' in venue time.
     * @return array{ok:bool,message:string}
     */
    public static function decide(string $status, string $startDate, string $endDate, string $today): array
    {
        if ($status !== 'active') {
            return ['ok' => false, 'message' => 'This membership is not active.'];
        }
        if ($today < substr($startDate, 0, 10)) {
            return ['ok' => false, 'message' => 'This membership starts on ' . substr($startDate, 0, 10) . '.'];
        }
        if ($today > substr($endDate, 0, 10)) {
            return ['ok' => false, 'message' => 'This membership ended on ' . substr($endDate, 0, 10) . '. Renew it at the desk.'];
        }
        return ['ok' => true, 'message' => 'Welcome in.'];
    }

    /** Whole days left including today, never below zero. */
    public static function daysLeft(string $endDate, string $today): int
    {
        $end = new DateTimeImmutable(substr($endDate, 0, 10));
        $now = new DateTimeImmutable($today);
        return $now > $end ? 0 : (int)$now->diff($end)->days + 1;
    }

    /** Adds the pass code column and the visits table. Safe to call on every request. */
    public static function ensureSchema(PDO $db): void
    {
        try { $db->exec('ALTER TABLE user_subscriptions ADD COLUMN check_in_code CHAR(8) NULL DEFAULT NULL'); } catch (PDOException $e) {}
        try { $db->exec('ALTER TABLE user_subscriptions ADD UNIQUE INDEX uq_sub_check_in_code (check_in_code)'); } catch (PDOException $e) {}
        $db->exec("CREATE TABLE IF NOT EXISTS member_visits (
            id              INT AUTO_INCREMENT PRIMARY KEY,
            subscription_id INT NOT NULL,
            user_id         INT NOT NULL,
            court_id        INT NOT NULL,
            visit_date      DATE NOT NULL,
            visited_at      DATETIME NOT NULL,
            checked_in_by   INT NULL,
            UNIQUE KEY uq_member_visit_day (subscription_id, visit_date),
            INDEX idx_member_visits_court (court_id, visit_date)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
    }

    /** Existing code, or a new unique one saved on the subscription. */
    public static function ensureCode(PDO $db, int $subscriptionId, ?string $current): string
    {
        if ($current !== null && $current !== '') {
            return $current;
        }
        $save = $db->prepare('UPDATE user_subscriptions SET check_in_code = ? WHERE id = ? AND check_in_code IS NULL');
        for ($attempt = 0; $attempt < 5; $attempt++) {
            try {
                $save->execute([TournamentCheckIn::code(), $subscriptionId]);
            } catch (PDOException $e) {
                continue; // unique collision; draw again
            }
            break;
        }
        $read = $db->prepare('SELECT check_in_code FROM user_subscriptions WHERE id = ?');
        $read->execute([$subscriptionId]);
        $stored = (string)$read->fetchColumn();
        if ($stored === '') {
            throw new RuntimeException('Could not create a member pass.');
        }
        return $stored;
    }
}
