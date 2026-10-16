-- Chat system tables (WhatsApp/Instagram-style groups + DMs)

CREATE TABLE IF NOT EXISTS chat_groups (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    name        VARCHAR(255) DEFAULT NULL,
    icon_url    VARCHAR(500) DEFAULT NULL,
    description TEXT DEFAULT NULL,
    type        ENUM('dm','group') NOT NULL DEFAULT 'group',
    created_by  INT DEFAULT NULL,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS chat_members (
    id        INT AUTO_INCREMENT PRIMARY KEY,
    group_id  INT NOT NULL,
    user_id   INT NOT NULL,
    role      ENUM('admin','member') NOT NULL DEFAULT 'member',
    muted     TINYINT(1) NOT NULL DEFAULT 0,
    joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY idx_group_user (group_id, user_id),
    FOREIGN KEY (group_id) REFERENCES chat_groups(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id)  REFERENCES users(id)       ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS chat_messages (
    id         INT AUTO_INCREMENT PRIMARY KEY,
    group_id   INT NOT NULL,
    sender_id  INT NOT NULL,
    content    TEXT NOT NULL,
    image_url  VARCHAR(500) DEFAULT NULL,
    reply_to   INT DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (group_id)  REFERENCES chat_groups(id)    ON DELETE CASCADE,
    FOREIGN KEY (sender_id) REFERENCES users(id)          ON DELETE CASCADE,
    FOREIGN KEY (reply_to)  REFERENCES chat_messages(id)  ON DELETE SET NULL,
    INDEX idx_chatmsg_group (group_id, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS chat_read_status (
    group_id           INT NOT NULL,
    user_id            INT NOT NULL,
    last_read_msg_id   INT NOT NULL DEFAULT 0,
    PRIMARY KEY (group_id, user_id),
    FOREIGN KEY (group_id) REFERENCES chat_groups(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id)  REFERENCES users(id)       ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS chat_reactions (
    id         INT AUTO_INCREMENT PRIMARY KEY,
    message_id INT NOT NULL,
    user_id    INT NOT NULL,
    emoji      VARCHAR(10) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY idx_reaction_unique (message_id, user_id, emoji),
    FOREIGN KEY (message_id) REFERENCES chat_messages(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id)    REFERENCES users(id)         ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
