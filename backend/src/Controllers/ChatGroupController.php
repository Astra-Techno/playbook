<?php

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../Push.php';

class ChatGroupController {

    /**
     * GET /api/chat/groups
     * Returns all chat groups the user is a member of, with last message + unread count.
     */
    public function index() {
        $authUser = Auth::require();
        $userId   = (int)$authUser['id'];
        $db       = Database::getConnection();

        $stmt = $db->prepare("
            SELECT g.id, g.name, g.icon_url, g.description, g.type, g.created_by, g.created_at,
                   cm.role AS my_role, cm.muted,
                   lm.content AS last_message, lm.created_at AS last_message_at,
                   lm_user.name AS last_message_sender,
                   lm.image_url AS last_message_image,
                   COALESCE(unread.cnt, 0) AS unread_count,
                   member_info.member_count
            FROM chat_members cm
            JOIN chat_groups g ON g.id = cm.group_id
            -- Last message
            LEFT JOIN (
                SELECT m1.group_id, m1.content, m1.created_at, m1.sender_id, m1.image_url
                FROM chat_messages m1
                INNER JOIN (
                    SELECT group_id, MAX(id) AS max_id
                    FROM chat_messages
                    GROUP BY group_id
                ) m2 ON m1.id = m2.max_id
            ) lm ON lm.group_id = g.id
            LEFT JOIN users lm_user ON lm_user.id = lm.sender_id
            -- Unread count
            LEFT JOIN (
                SELECT cm2.group_id,
                       COUNT(msg.id) AS cnt
                FROM chat_members cm2
                LEFT JOIN chat_read_status rs ON rs.group_id = cm2.group_id AND rs.user_id = cm2.user_id
                INNER JOIN chat_messages msg ON msg.group_id = cm2.group_id AND msg.id > COALESCE(rs.last_read_msg_id, 0)
                WHERE cm2.user_id = ?
                GROUP BY cm2.group_id
            ) unread ON unread.group_id = g.id
            -- Member count
            LEFT JOIN (
                SELECT group_id, COUNT(*) AS member_count
                FROM chat_members
                GROUP BY group_id
            ) member_info ON member_info.group_id = g.id
            WHERE cm.user_id = ?
            ORDER BY COALESCE(lm.created_at, g.created_at) DESC
            LIMIT 100
        ");
        $stmt->execute([$userId, $userId]);
        $groups = $stmt->fetchAll(PDO::FETCH_ASSOC);

        // For DMs, attach the other user's info
        foreach ($groups as &$group) {
            $group['unread_count'] = (int)$group['unread_count'];
            $group['member_count'] = (int)$group['member_count'];
            if ($group['type'] === 'dm') {
                $other = $db->prepare("
                    SELECT u.id, u.name, u.avatar_url, u.phone
                    FROM chat_members cm
                    JOIN users u ON u.id = cm.user_id
                    WHERE cm.group_id = ? AND cm.user_id != ?
                    LIMIT 1
                ");
                $other->execute([$group['id'], $userId]);
                $group['dm_user'] = $other->fetch(PDO::FETCH_ASSOC) ?: null;
            }
        }

        echo json_encode(['groups' => $groups]);
    }

    /**
     * POST /api/chat/groups  { name, description?, member_ids: [int,...], type?: 'group'|'dm' }
     * Creates a new group or DM conversation.
     */
    public function create() {
        $authUser  = Auth::require();
        $userId    = (int)$authUser['id'];
        $data      = json_decode(file_get_contents('php://input'), true) ?: [];
        $name      = trim($data['name'] ?? '');
        $desc      = trim($data['description'] ?? '');
        $memberIds = array_map('intval', $data['member_ids'] ?? []);
        $type      = ($data['type'] ?? 'group') === 'dm' ? 'dm' : 'group';

        if ($type === 'dm') {
            if (count($memberIds) !== 1) {
                http_response_code(400);
                echo json_encode(['message' => 'DM requires exactly one other member_id']);
                return;
            }
            $otherId = $memberIds[0];
            // Check if DM already exists between these two users
            $db = Database::getConnection();
            $existing = $db->prepare("
                SELECT g.id FROM chat_groups g
                JOIN chat_members cm1 ON cm1.group_id = g.id AND cm1.user_id = ?
                JOIN chat_members cm2 ON cm2.group_id = g.id AND cm2.user_id = ?
                WHERE g.type = 'dm'
                LIMIT 1
            ");
            $existing->execute([$userId, $otherId]);
            $row = $existing->fetch(PDO::FETCH_ASSOC);
            if ($row) {
                echo json_encode(['group_id' => (int)$row['id'], 'existing' => true]);
                return;
            }
        } else {
            if (!$name) {
                http_response_code(400);
                echo json_encode(['message' => 'Group name is required']);
                return;
            }
            if (count($memberIds) < 1) {
                http_response_code(400);
                echo json_encode(['message' => 'At least one member required']);
                return;
            }
        }

        $db = Database::getConnection();
        $db->beginTransaction();
        try {
            $stmt = $db->prepare("INSERT INTO chat_groups (name, description, type, created_by) VALUES (?,?,?,?)");
            $stmt->execute([$name ?: null, $desc ?: null, $type, $userId]);
            $groupId = (int)$db->lastInsertId();

            // Add creator as admin
            $db->prepare("INSERT INTO chat_members (group_id, user_id, role) VALUES (?,?,'admin')")
               ->execute([$groupId, $userId]);

            // Add other members
            $ins = $db->prepare("INSERT IGNORE INTO chat_members (group_id, user_id, role) VALUES (?,?,'member')");
            foreach ($memberIds as $mid) {
                if ($mid !== $userId) $ins->execute([$groupId, $mid]);
            }

            $db->commit();

            // Notify members
            $senderName = $authUser['name'] ?? 'Someone';
            foreach ($memberIds as $mid) {
                if ($mid === $userId) continue;
                Push::sendToUser($mid, $senderName, $type === 'dm' ? 'Started a conversation with you' : "Added you to $name", ['type' => 'chat_group', 'group_id' => (string)$groupId]);
            }

            http_response_code(201);
            echo json_encode(['group_id' => $groupId]);
        } catch (Exception $e) {
            $db->rollBack();
            http_response_code(500);
            echo json_encode(['message' => 'Failed to create group']);
        }
    }

    /**
     * GET /api/chat/groups/:id
     * Returns group details + members.
     */
    public function show(int $groupId) {
        $authUser = Auth::require();
        $userId   = (int)$authUser['id'];
        $db       = Database::getConnection();

        // Verify membership
        if (!$this->isMember($db, $groupId, $userId)) {
            http_response_code(403);
            echo json_encode(['message' => 'Not a member']);
            return;
        }

        $stmt = $db->prepare("SELECT * FROM chat_groups WHERE id = ?");
        $stmt->execute([$groupId]);
        $group = $stmt->fetch(PDO::FETCH_ASSOC);
        if (!$group) {
            http_response_code(404);
            echo json_encode(['message' => 'Group not found']);
            return;
        }

        // Members
        $members = $db->prepare("
            SELECT u.id, u.name, u.avatar_url, u.phone, cm.role, cm.muted, cm.joined_at
            FROM chat_members cm
            JOIN users u ON u.id = cm.user_id
            WHERE cm.group_id = ?
            ORDER BY cm.role DESC, cm.joined_at ASC
        ");
        $members->execute([$groupId]);

        $group['members'] = $members->fetchAll(PDO::FETCH_ASSOC);
        echo json_encode(['group' => $group]);
    }

    /**
     * PUT /api/chat/groups/:id  { name?, description?, icon_url? }
     * Update group info (admin only).
     */
    public function update(int $groupId) {
        $authUser = Auth::require();
        $userId   = (int)$authUser['id'];
        $db       = Database::getConnection();

        if (!$this->isAdmin($db, $groupId, $userId)) {
            http_response_code(403);
            echo json_encode(['message' => 'Only group admins can edit']);
            return;
        }

        $data = json_decode(file_get_contents('php://input'), true) ?: [];
        $sets = [];
        $vals = [];
        foreach (['name', 'description', 'icon_url'] as $field) {
            if (array_key_exists($field, $data)) {
                $sets[] = "$field = ?";
                $vals[] = $data[$field];
            }
        }
        if (empty($sets)) {
            http_response_code(400);
            echo json_encode(['message' => 'Nothing to update']);
            return;
        }
        $vals[] = $groupId;
        $db->prepare("UPDATE chat_groups SET " . implode(', ', $sets) . " WHERE id = ?")->execute($vals);
        echo json_encode(['message' => 'Updated']);
    }

    /**
     * DELETE /api/chat/groups/:id
     * Delete group (admin only).
     */
    public function delete(int $groupId) {
        $authUser = Auth::require();
        $userId   = (int)$authUser['id'];
        $db       = Database::getConnection();

        if (!$this->isAdmin($db, $groupId, $userId)) {
            http_response_code(403);
            echo json_encode(['message' => 'Only group admins can delete']);
            return;
        }

        $db->prepare("DELETE FROM chat_groups WHERE id = ?")->execute([$groupId]);
        echo json_encode(['message' => 'Group deleted']);
    }

    /**
     * POST /api/chat/groups/:id/members  { user_ids: [int,...] }
     * Add members (admin only).
     */
    public function addMembers(int $groupId) {
        $authUser = Auth::require();
        $userId   = (int)$authUser['id'];
        $db       = Database::getConnection();

        if (!$this->isAdmin($db, $groupId, $userId)) {
            http_response_code(403);
            echo json_encode(['message' => 'Only admins can add members']);
            return;
        }

        $data    = json_decode(file_get_contents('php://input'), true) ?: [];
        $userIds = array_map('intval', $data['user_ids'] ?? []);
        if (empty($userIds)) {
            http_response_code(400);
            echo json_encode(['message' => 'user_ids required']);
            return;
        }

        $group = $db->prepare("SELECT name FROM chat_groups WHERE id = ?");
        $group->execute([$groupId]);
        $groupName = $group->fetchColumn() ?: 'a group';

        $ins  = $db->prepare("INSERT IGNORE INTO chat_members (group_id, user_id, role) VALUES (?,?,'member')");
        $added = 0;
        foreach ($userIds as $uid) {
            $ins->execute([$groupId, $uid]);
            $added += $ins->rowCount();
            Push::sendToUser($uid, $authUser['name'] ?? 'Someone', "Added you to $groupName", ['type' => 'chat_group', 'group_id' => (string)$groupId]);
        }
        echo json_encode(['message' => "Added $added member(s)"]);
    }

    /**
     * DELETE /api/chat/groups/:id/members/:userId
     * Remove a member (admin only, or self-leave).
     */
    public function removeMember(int $groupId, int $targetUserId) {
        $authUser = Auth::require();
        $userId   = (int)$authUser['id'];
        $db       = Database::getConnection();

        $isSelf = ($userId === $targetUserId);
        if (!$isSelf && !$this->isAdmin($db, $groupId, $userId)) {
            http_response_code(403);
            echo json_encode(['message' => 'Only admins can remove members']);
            return;
        }

        $db->prepare("DELETE FROM chat_members WHERE group_id = ? AND user_id = ?")->execute([$groupId, $targetUserId]);
        $db->prepare("DELETE FROM chat_read_status WHERE group_id = ? AND user_id = ?")->execute([$groupId, $targetUserId]);

        // If last admin leaves, promote oldest member to admin
        if ($isSelf) {
            $adminCount = $db->prepare("SELECT COUNT(*) FROM chat_members WHERE group_id = ? AND role = 'admin'");
            $adminCount->execute([$groupId]);
            if ((int)$adminCount->fetchColumn() === 0) {
                $oldest = $db->prepare("SELECT user_id FROM chat_members WHERE group_id = ? ORDER BY joined_at ASC LIMIT 1");
                $oldest->execute([$groupId]);
                $newAdmin = $oldest->fetchColumn();
                if ($newAdmin) {
                    $db->prepare("UPDATE chat_members SET role = 'admin' WHERE group_id = ? AND user_id = ?")
                       ->execute([$groupId, $newAdmin]);
                } else {
                    // No members left — delete group
                    $db->prepare("DELETE FROM chat_groups WHERE id = ?")->execute([$groupId]);
                }
            }
        }

        echo json_encode(['message' => $isSelf ? 'Left group' : 'Member removed']);
    }

    /**
     * PUT /api/chat/groups/:id/mute  { muted: bool }
     * Toggle mute for current user in this group.
     */
    public function toggleMute(int $groupId) {
        $authUser = Auth::require();
        $userId   = (int)$authUser['id'];
        $db       = Database::getConnection();

        $data  = json_decode(file_get_contents('php://input'), true) ?: [];
        $muted = !empty($data['muted']) ? 1 : 0;

        $db->prepare("UPDATE chat_members SET muted = ? WHERE group_id = ? AND user_id = ?")
           ->execute([$muted, $groupId, $userId]);
        echo json_encode(['muted' => (bool)$muted]);
    }

    /**
     * GET /api/chat/users/search?q=name_or_phone
     * Search users for member picker.
     */
    public function searchUsers() {
        Auth::require();
        $q = trim($_GET['q'] ?? '');
        if (strlen($q) < 2) {
            echo json_encode(['users' => []]);
            return;
        }

        $db   = Database::getConnection();
        $like = "%$q%";
        $stmt = $db->prepare("
            SELECT id, name, avatar_url, phone
            FROM users
            WHERE name LIKE ? OR phone LIKE ?
            LIMIT 20
        ");
        $stmt->execute([$like, $like]);
        echo json_encode(['users' => $stmt->fetchAll(PDO::FETCH_ASSOC)]);
    }

    // -- Helpers --

    private function isMember(PDO $db, int $groupId, int $userId): bool {
        $stmt = $db->prepare("SELECT 1 FROM chat_members WHERE group_id = ? AND user_id = ? LIMIT 1");
        $stmt->execute([$groupId, $userId]);
        return (bool)$stmt->fetch();
    }

    private function isAdmin(PDO $db, int $groupId, int $userId): bool {
        $stmt = $db->prepare("SELECT 1 FROM chat_members WHERE group_id = ? AND user_id = ? AND role = 'admin' LIMIT 1");
        $stmt->execute([$groupId, $userId]);
        return (bool)$stmt->fetch();
    }
}
