<?php

/**
 * One MySQL named lock per venue so check-then-insert cannot run twice.
 * The lock is held on the shared PDO connection and must be released
 * on that same connection.
 */
class SlotLock
{
    public static function name(int $courtId): string
    {
        return 'kocourt-court-' . $courtId;
    }

    public static function hold(PDO $db, int $courtId): bool
    {
        $stmt = $db->prepare('SELECT GET_LOCK(?, 5)');
        $stmt->execute([self::name($courtId)]);
        return (int)$stmt->fetchColumn() === 1;
    }

    public static function release(PDO $db, int $courtId): void
    {
        $stmt = $db->prepare('SELECT RELEASE_LOCK(?)');
        $stmt->execute([self::name($courtId)]);
    }
}
