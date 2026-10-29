<?php
require_once __DIR__ . '/../CommerceSettings.php';

class SettingsController {
    private function scope(): ?int {
        $courtId = isset($_GET['court_id']) ? filter_var($_GET['court_id'], FILTER_VALIDATE_INT) : null;
        if ($courtId !== null && (!$courtId || $courtId < 1)) throw new InvalidArgumentException('Invalid venue');
        if ($courtId) {
            $stmt = Database::getConnection()->prepare('SELECT id FROM courts WHERE id = ?');
            $stmt->execute([$courtId]);
            if (!$stmt->fetchColumn()) throw new InvalidArgumentException('Venue not found');
        }
        return $courtId;
    }

    public function handle(): void {
        $user = Auth::requireAdmin();
        $db = Database::getConnection();
        try {
            $courtId = $this->scope();
            $key = CommerceSettings::KEY . ($courtId ? '.venue.' . $courtId : '');
            if (in_array($_SERVER['REQUEST_METHOD'], ['PUT', 'DELETE'], true)) {
                $reset = $_SERVER['REQUEST_METHOD'] === 'DELETE';
                if ($reset && !$courtId) throw new InvalidArgumentException('Platform policy cannot be deleted');
                $body = json_decode(file_get_contents('php://input'), true, 512, JSON_THROW_ON_ERROR);
                $values = $reset ? ['venue.gst_registered' => false] : ($body['values'] ?? null);
                if (!is_array($values) || array_is_list($values)) throw new InvalidArgumentException('values must be a settings object');
                if ($courtId) {
                    foreach (array_keys($values) as $field) {
                        if (!str_starts_with($field, 'venue.') && !str_starts_with($field, 'cancellation.') && !str_starts_with($field, 'booking.')) throw new InvalidArgumentException('Only venue tax, booking and cancellation settings can be overridden');
                    }
                }
                // Serialize saves; stale forms fail instead of overwriting newer policy.
                $db->beginTransaction();
                $global = $db->prepare('SELECT `value` FROM config WHERE `key` = ? FOR UPDATE');
                $global->execute([CommerceSettings::KEY]);
                $stmt = $db->prepare('SELECT `value` FROM config WHERE `key` = ? FOR UPDATE');
                $stmt->execute([$key]);
                $old = $stmt->fetchColumn();
                $revision = hash('sha256', json_encode(CommerceSettings::load($db, $courtId)));
                if (!hash_equals($revision, (string)($body['revision'] ?? ''))) {
                    $db->rollBack(); http_response_code(409);
                    echo json_encode(['message' => 'Settings changed. Reload before saving.']); return;
                }
                $merged = CommerceSettings::normalize(array_replace(CommerceSettings::load($db, $courtId), $values));
                if (!$courtId) {
                    if ($merged['venue.gst_registered'] || $merged['venue.gstin'] !== '') throw new InvalidArgumentException('Configure venue GST registration individually by selecting a venue');
                    $overrides = $db->query("SELECT `value` FROM config WHERE `key` LIKE 'commerce_policy.venue.%'")->fetchAll(PDO::FETCH_COLUMN);
                    foreach ($overrides as $override) CommerceSettings::normalize(array_replace($merged, json_decode($override, true, 512, JSON_THROW_ON_ERROR)));
                }
                $next = $courtId ? array_replace(json_decode($old ?: '{}', true), $values) : $merged;
                $json = $reset ? null : json_encode($next, JSON_THROW_ON_ERROR);
                if ($reset) $db->prepare('DELETE FROM config WHERE `key` = ?')->execute([$key]);
                else $db->prepare('INSERT INTO config (`key`, `value`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `value` = VALUES(`value`)')->execute([$key, $json]);
                $db->prepare('INSERT INTO config_audit (config_key, old_value, new_value, actor_id) VALUES (?, ?, ?, ?)')->execute([$key, $old ?: null, $json, (int)$user['id']]);
                $db->commit();
            } elseif ($_SERVER['REQUEST_METHOD'] !== 'GET') {
                http_response_code(405); echo json_encode(['message' => 'Method not allowed']); return;
            }
            $values = CommerceSettings::load($db, $courtId);
            $history = $db->prepare('SELECT id, actor_id, created_at FROM config_audit WHERE config_key = ? ORDER BY id DESC LIMIT 10');
            $history->execute([$key]);
            echo json_encode(['values' => $values, 'schema' => CommerceSettings::schema(), 'revision' => hash('sha256', json_encode($values)), 'history' => $history->fetchAll(PDO::FETCH_ASSOC)]);
        } catch (InvalidArgumentException | JsonException $e) {
            if ($db->inTransaction()) $db->rollBack();
            http_response_code(422); echo json_encode(['message' => $e->getMessage()]);
        }
    }
}
