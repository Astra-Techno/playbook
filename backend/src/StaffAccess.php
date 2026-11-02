<?php

/** What a venue staff role may do. A role applies only to the venue it was granted on. */
final class StaffAccess
{
    public const MANAGER = 'manager';
    public const VIEWER = 'viewer';

    /** @var array<string, array<string, bool>> */
    private const ACTIONS = [
        self::MANAGER => [
            'calendar' => true,
            'bookings' => true,
            'walk_in' => true,
            'attendance' => true,
            'blocks' => true,
            'customers' => true,
        ],
        self::VIEWER => [
            'calendar' => true,
            'bookings' => true,
            'walk_in' => false,
            'attendance' => false,
            'blocks' => false,
            'customers' => false,
        ],
    ];

    public static function role(?string $value): ?string
    {
        $value = trim((string)$value);
        return isset(self::ACTIONS[$value]) ? $value : null;
    }

    public static function allows(?string $role, string $action, bool $sameVenue): bool
    {
        if (!$sameVenue) {
            return false;
        }
        $role = self::role($role);
        if ($role === null) {
            return false;
        }
        return self::ACTIONS[$role][$action] ?? false;
    }
}
