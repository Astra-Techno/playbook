<?php

require_once __DIR__ . '/StaffAccess.php';

/** Players who booked a venue. Phone numbers stay off both the owner list and the public regulars list. */
final class CustomerDirectory
{
    public static function canView(bool $isAdmin, bool $isOwner, ?string $staffRole): bool
    {
        return $isAdmin || $isOwner || StaffAccess::allows($staffRole, 'customers', true);
    }

    /** @param array<string,mixed> $row */
    public static function row(array $row): array
    {
        return [
            'id' => (int)($row['id'] ?? 0),
            'name' => (string)($row['name'] ?? ''),
            'booking_count' => (int)($row['booking_count'] ?? 0),
            'last_played' => $row['last_played'] ?? null,
        ];
    }

    /** @param array<string,mixed> $row */
    public static function regular(array $row): array
    {
        return [
            'id' => (int)($row['id'] ?? 0),
            'name' => (string)($row['name'] ?? ''),
            'avatar_url' => $row['avatar_url'] ?? null,
            'booking_count' => (int)($row['booking_count'] ?? 0),
        ];
    }
}
