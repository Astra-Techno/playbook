<?php

/**
 * Auth helper — validates Bearer token from Authorization header.
 *
 * Roles: 'admin' (full access) and 'user' (default).
 * Venue ownership is determined by courts.owner_id, not user role.
 * Staff access is via the court_staff table.
 *
 * Usage:
 *   $user = Auth::user();          // returns user row or null
 *   Auth::require();               // halts with 401 if not authenticated
 *   Auth::requireAdmin();          // halts with 401/403 if not admin
 *   Auth::requireSelf(int $id);    // halts unless token belongs to $id or admin
 */
class Auth
{
    private static ?array $resolved = null; // cache per request

    /** Return the authenticated user row (or null if no/invalid token). */
    public static function user(): ?array
    {
        if (self::$resolved !== null) return self::$resolved ?: null;

        $header = $_SERVER['HTTP_AUTHORIZATION']
               ?? $_SERVER['REDIRECT_HTTP_AUTHORIZATION']
               ?? '';

        if ($header === '' && function_exists('getallheaders')) {
            foreach (getallheaders() as $name => $value) {
                if (strcasecmp((string) $name, 'Authorization') === 0) {
                    $header = (string) $value;
                    break;
                }
            }
        }

        if (!preg_match('/Bearer\s+(\S+)/i', $header, $m)) {
            self::$resolved = [];
            return null;
        }

        $token = $m[1];
        $db    = Database::getConnection();
        $stmt  = $db->prepare(
            "SELECT id, name, phone, role, avatar_url FROM users WHERE auth_token = ? LIMIT 1"
        );
        $stmt->execute([$token]);
        $row = $stmt->fetch(PDO::FETCH_ASSOC) ?: null;

        self::$resolved = $row ?? [];
        return $row;
    }

    /** Halt with 401 if not authenticated. Returns user row. */
    public static function require(): array
    {
        $user = self::user();
        if (!$user) {
            http_response_code(401);
            echo json_encode(['error' => 'Unauthenticated']);
            exit();
        }
        return $user;
    }

    /**
     * @deprecated Use Auth::require() instead. Any authenticated user can manage venues.
     * Kept as alias to avoid breaking existing calls during migration.
     */
    public static function requireOwner(): array
    {
        return self::require();
    }

    /** Halt unless authenticated user is admin. Returns user row. */
    public static function requireAdmin(): array
    {
        $user = self::require();
        if ($user['role'] !== 'admin') {
            http_response_code(403);
            echo json_encode(['error' => 'Admin access required']);
            exit();
        }
        return $user;
    }

    /**
     * Halt unless the token belongs to $userId or is an admin.
     * Prevents one user from modifying another user's data.
     */
    public static function requireSelf(int $userId): array
    {
        $user = self::require();
        if ((int)$user['id'] !== $userId && $user['role'] !== 'admin') {
            http_response_code(403);
            echo json_encode(['error' => 'Forbidden']);
            exit();
        }
        return $user;
    }
}
