<?php

/**
 * Auth helper — validates Bearer token from Authorization header.
 *
 * Usage:
 *   $user = Auth::user();          // returns user row or null
 *   Auth::require();               // halts with 401 if not authenticated
 *   Auth::requireOwner();          // halts with 401/403 if not owner/admin
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

    /** Halt unless authenticated user is owner or admin. Returns user row. */
    public static function requireOwner(): array
    {
        $user = self::require();
        if (!in_array($user['role'], ['owner', 'admin'], true)) {
            http_response_code(403);
            echo json_encode(['error' => 'Owner account required']);
            exit();
        }
        return $user;
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
