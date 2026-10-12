<?php

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../Push.php';

class ChatMessageController {

    /**
     * GET /api/chat/groups/:id/messages?before=msgId&limit=50
     * Returns messages for a group, paginated (newest first, reversed for display).
     * Also marks messages as read up to the latest message.
     */
    public function index(int $groupId) {
        $authUser = Auth::require();
        $userId   = (int)$authUser['id'];
        $db       = Database::getConnection();

        if (!$this->isMember($db, $groupId, $userId)) {
            http_response_code(403);
            echo json_encode(['message' => 'Not a member']);
            return;
        }

        $before = (int)($_GET['before'] ?? 0);
        $limit  = min((int)($_GET['limit'] ?? 50), 100);

        $where = $before > 0 ? "AND m.id < ?" : "";
        $params = $before > 0 ? [$groupId, $before, $limit] : [$groupId, $limit];

        $stmt = $db->prepare("
            SELECT m.id, m.group_id, m.sender_id, m.content, m.image_url, m.reply_to, m.created_at,
                   u.name AS sender_name, u.avatar_url AS sender_avatar,
                   rm.content AS reply_content, rm.sender_id AS reply_sender_id,
                   ru.name AS reply_sender_name
            FROM chat_messages m
            JOIN users u ON u.id = m.sender_id
            LEFT JOIN chat_messages rm ON rm.id = m.reply_to
            LEFT JOIN users ru ON ru.id = rm.sender_id
            WHERE m.group_id = ? $where
            ORDER BY m.id DESC
            LIMIT ?
        ");
        $stmt->execute($params);
        $messages = $stmt->fetchAll(PDO::FETCH_ASSOC);

        // Attach reactions to each message
        if (!empty($messages)) {
            $msgIds = array_column($messages, 'id');
            $placeholders = implode(',', array_fill(0, count($msgIds), '?'));
            $rStmt = $db->prepare("
                SELECT r.message_id, r.emoji, r.user_id, u.name AS user_name
                FROM chat_reactions r
                JOIN users u ON u.id = r.user_id
                WHERE r.message_id IN ($placeholders)
            ");
            $rStmt->execute($msgIds);
            $reactions = [];
            while ($r = $rStmt->fetch(PDO::FETCH_ASSOC)) {
                $reactions[$r['message_id']][] = $r;
            }
            foreach ($messages as &$msg) {
                $msg['reactions'] = $reactions[$msg['id']] ?? [];
            }
        }

        // Mark as read (update read status to latest message in this batch)
        if (!empty($messages)) {
            $latestId = max(array_column($messages, 'id'));
            $db->prepare("
                INSERT INTO chat_read_status (group_id, user_id, last_read_msg_id)
                VALUES (?, ?, ?)
                ON DUPLICATE KEY UPDATE last_read_msg_id = GREATEST(last_read_msg_id, VALUES(last_read_msg_id))
            ")->execute([$groupId, $userId, $latestId]);
        }

        // Reverse to chronological order for client display
        $messages = array_reverse($messages);

        echo json_encode(['messages' => $messages]);
    }

    /**
     * POST /api/chat/groups/:id/messages  { content, image_url?, reply_to? }
     * Send a message to the group.
     */
    public function create(int $groupId) {
        $authUser = Auth::require();
        $userId   = (int)$authUser['id'];
        $db       = Database::getConnection();

        if (!$this->isMember($db, $groupId, $userId)) {
            http_response_code(403);
            echo json_encode(['message' => 'Not a member']);
            return;
        }

        $data     = json_decode(file_get_contents('php://input'), true) ?: [];
        $content  = htmlspecialchars(strip_tags(trim($data['content'] ?? '')));
        $imageUrl = trim($data['image_url'] ?? '');
        $replyTo  = (int)($data['reply_to'] ?? 0) ?: null;

        if (!$content && !$imageUrl) {
            http_response_code(400);
            echo json_encode(['message' => 'content or image_url required']);
            return;
        }

        $stmt = $db->prepare("INSERT INTO chat_messages (group_id, sender_id, content, image_url, reply_to) VALUES (?,?,?,?,?)");
        $stmt->execute([$groupId, $userId, $content ?: '', $imageUrl ?: null, $replyTo]);
        $msgId = (int)$db->lastInsertId();

        // Update sender's own read status
        $db->prepare("
            INSERT INTO chat_read_status (group_id, user_id, last_read_msg_id)
            VALUES (?, ?, ?)
            ON DUPLICATE KEY UPDATE last_read_msg_id = GREATEST(last_read_msg_id, VALUES(last_read_msg_id))
        ")->execute([$groupId, $userId, $msgId]);

        // Push notification to non-muted members
        $senderName = $authUser['name'] ?? 'Someone';
        $members = $db->prepare("
            SELECT cm.user_id FROM chat_members cm
            WHERE cm.group_id = ? AND cm.user_id != ? AND cm.muted = 0
        ");
        $members->execute([$groupId, $userId]);

        // Get group name for notification
        $grp = $db->prepare("SELECT name, type FROM chat_groups WHERE id = ?");
        $grp->execute([$groupId]);
        $groupInfo = $grp->fetch(PDO::FETCH_ASSOC);
        $title = $groupInfo['type'] === 'dm' ? $senderName : ($senderName . ' in ' . ($groupInfo['name'] ?? 'group'));
        $body  = $imageUrl && !$content ? '📷 Photo' : $content;

        while ($member = $members->fetch(PDO::FETCH_ASSOC)) {
            Push::sendToUser(
                (int)$member['user_id'],
                $title,
                substr($body, 0, 200),
                ['type' => 'chat_message', 'group_id' => (string)$groupId, 'message_id' => (string)$msgId]
            );
            // In-app notification
            $db->prepare("INSERT INTO user_notifications (user_id, type, title, body) VALUES (?,?,?,?)")
               ->execute([$member['user_id'], 'chat', $title, substr($body, 0, 200)]);
        }

        http_response_code(201);
        echo json_encode([
            'id'         => $msgId,
            'group_id'   => $groupId,
            'sender_id'  => $userId,
            'content'    => $content,
            'image_url'  => $imageUrl ?: null,
            'reply_to'   => $replyTo,
            'created_at' => date('Y-m-d H:i:s'),
            'sender_name' => $senderName,
            'sender_avatar' => $authUser['avatar_url'] ?? null,
        ]);
    }

    /**
     * POST /api/chat/messages/:id/reactions  { emoji: string }
     * Toggle a reaction on a message.
     */
    public function toggleReaction(int $messageId) {
        $authUser = Auth::require();
        $userId   = (int)$authUser['id'];
        $db       = Database::getConnection();

        // Verify message exists and user is a member of its group
        $msg = $db->prepare("SELECT group_id FROM chat_messages WHERE id = ?");
        $msg->execute([$messageId]);
        $row = $msg->fetch(PDO::FETCH_ASSOC);
        if (!$row || !$this->isMember($db, (int)$row['group_id'], $userId)) {
            http_response_code(403);
            echo json_encode(['message' => 'Not authorized']);
            return;
        }

        $data  = json_decode(file_get_contents('php://input'), true) ?: [];
        $emoji = trim($data['emoji'] ?? '');
        if (!$emoji) {
            http_response_code(400);
            echo json_encode(['message' => 'emoji required']);
            return;
        }

        // Toggle: if exists remove, else add
        $existing = $db->prepare("SELECT id FROM chat_reactions WHERE message_id = ? AND user_id = ? AND emoji = ?");
        $existing->execute([$messageId, $userId, $emoji]);
        if ($existing->fetch()) {
            $db->prepare("DELETE FROM chat_reactions WHERE message_id = ? AND user_id = ? AND emoji = ?")
               ->execute([$messageId, $userId, $emoji]);
            echo json_encode(['action' => 'removed', 'emoji' => $emoji]);
        } else {
            $db->prepare("INSERT INTO chat_reactions (message_id, user_id, emoji) VALUES (?,?,?)")
               ->execute([$messageId, $userId, $emoji]);
            echo json_encode(['action' => 'added', 'emoji' => $emoji]);
        }
    }

    /**
     * POST /api/chat/groups/:id/read  { message_id: int }
     * Mark messages as read up to a specific message.
     */
    public function markRead(int $groupId) {
        $authUser  = Auth::require();
        $userId    = (int)$authUser['id'];
        $db        = Database::getConnection();
        $data      = json_decode(file_get_contents('php://input'), true) ?: [];
        $messageId = (int)($data['message_id'] ?? 0);

        if (!$messageId) {
            http_response_code(400);
            echo json_encode(['message' => 'message_id required']);
            return;
        }

        $db->prepare("
            INSERT INTO chat_read_status (group_id, user_id, last_read_msg_id)
            VALUES (?, ?, ?)
            ON DUPLICATE KEY UPDATE last_read_msg_id = GREATEST(last_read_msg_id, VALUES(last_read_msg_id))
        ")->execute([$groupId, $userId, $messageId]);

        echo json_encode(['read_up_to' => $messageId]);
    }

    /**
     * GET /api/chat/groups/:id/read-status
     * Get read receipts for all members (which message each has read up to).
     */
    public function readStatus(int $groupId) {
        $authUser = Auth::require();
        $userId   = (int)$authUser['id'];
        $db       = Database::getConnection();

        if (!$this->isMember($db, $groupId, $userId)) {
            http_response_code(403);
            echo json_encode(['message' => 'Not a member']);
            return;
        }

        $stmt = $db->prepare("
            SELECT rs.user_id, rs.last_read_msg_id, u.name, u.avatar_url
            FROM chat_read_status rs
            JOIN users u ON u.id = rs.user_id
            WHERE rs.group_id = ?
        ");
        $stmt->execute([$groupId]);
        echo json_encode(['read_status' => $stmt->fetchAll(PDO::FETCH_ASSOC)]);
    }

    /**
     * GET /api/chat/unread-count
     * Total unread message count across all groups for the current user.
     */
    public function totalUnread() {
        $authUser = Auth::require();
        $userId   = (int)$authUser['id'];
        $db       = Database::getConnection();

        $stmt = $db->prepare("
            SELECT COALESCE(SUM(cnt), 0) AS total
            FROM (
                SELECT COUNT(msg.id) AS cnt
                FROM chat_members cm
                LEFT JOIN chat_read_status rs ON rs.group_id = cm.group_id AND rs.user_id = cm.user_id
                INNER JOIN chat_messages msg ON msg.group_id = cm.group_id AND msg.id > COALESCE(rs.last_read_msg_id, 0)
                WHERE cm.user_id = ?
            ) sub
        ");
        $stmt->execute([$userId]);
        echo json_encode(['count' => (int)$stmt->fetchColumn()]);
    }

    /**
     * POST /api/chat/groups/:id/typing
     * Broadcast typing indicator (returns list of who's typing; no persistent storage).
     */
    public function typing(int $groupId) {
        $authUser = Auth::require();
        // Typing indicators are ephemeral — just return OK.
        // Clients poll messages and can infer typing from recent activity.
        echo json_encode(['typing' => true]);
    }

    // -- Helpers --

    private function isMember(PDO $db, int $groupId, int $userId): bool {
        $stmt = $db->prepare("SELECT 1 FROM chat_members WHERE group_id = ? AND user_id = ? LIMIT 1");
        $stmt->execute([$groupId, $userId]);
        return (bool)$stmt->fetch();
    }
}
