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
            'members' => true,
            'coaching' => true,
            'equipment' => true,
        ],
        self::VIEWER => [
            'calendar' => true,
            'bookings' => true,
            'walk_in' => false,
            'attendance' => false,
            'blocks' => false,
            'customers' => false,
            'members' => false,
            'coaching' => false,
            'equipment' => false,
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

    /**
     * Admin, the venue owner, or staff whose role allows $action at this venue.
     * Pricing, plans, staff and venue settings stay owner-only: they are not staff actions.
     */
    public static function canAtVenue(PDO $db, int $courtId, array $user, string $action): bool
    {
        if (($user['role'] ?? '') === 'admin') {
            return true;
        }
        $owner = $db->prepare('SELECT owner_id FROM courts WHERE id = ?');
        $owner->execute([$courtId]);
        $ownerId = $owner->fetchColumn();
        if ($ownerId === false) {
            return false;
        }
        if ((int)$ownerId === (int)($user['id'] ?? 0)) {
            return true;
        }
        try {
            $staff = $db->prepare('SELECT role FROM court_staff WHERE court_id = ? AND user_id = ?');
            $staff->execute([$courtId, (int)($user['id'] ?? 0)]);
            $role = $staff->fetchColumn();
        } catch (PDOException $e) {
            return false; // no staff table yet: nobody but the owner
        }
        return self::allows($role === false ? null : (string)$role, $action, true);
    }
}
