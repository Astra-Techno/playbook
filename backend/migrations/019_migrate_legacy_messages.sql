-- Migrate legacy booking messages into DM chat groups
-- Each booking thread becomes a DM between the two participants

INSERT INTO chat_groups (name, description, type, created_by, created_at)
SELECT DISTINCT
    NULL,
    CONCAT('legacy_booking:', b.id),
    'dm',
    LEAST(m.sender_id, m.receiver_id),
    MIN(m.created_at)
FROM messages m
JOIN bookings b ON b.id = m.booking_id
GROUP BY b.id;

-- Add members to legacy DM groups
INSERT IGNORE INTO chat_members (group_id, user_id, role)
SELECT g.id, m.sender_id, 'member'
FROM chat_groups g
JOIN messages m ON CONCAT('legacy_booking:', m.booking_id) = g.description
WHERE g.type = 'dm' AND g.description LIKE 'legacy_booking:%'
GROUP BY g.id, m.sender_id;

INSERT IGNORE INTO chat_members (group_id, user_id, role)
SELECT g.id, m.receiver_id, 'member'
FROM chat_groups g
JOIN messages m ON CONCAT('legacy_booking:', m.booking_id) = g.description
WHERE g.type = 'dm' AND g.description LIKE 'legacy_booking:%'
GROUP BY g.id, m.receiver_id;

-- Copy messages into new chat_messages table
INSERT INTO chat_messages (group_id, sender_id, content, created_at)
SELECT g.id, m.sender_id, m.body, m.created_at
FROM messages m
JOIN bookings b ON b.id = m.booking_id
JOIN chat_groups g ON g.description = CONCAT('legacy_booking:', b.id)
WHERE g.type = 'dm' AND g.description LIKE 'legacy_booking:%'
ORDER BY m.created_at ASC;

-- Migrate slot messages into auto chat groups
INSERT INTO chat_groups (name, description, type, created_by, created_at)
SELECT DISTINCT
    CONCAT(c.name, ' · ', sm.slot_date, ' · ', sm.slot_time),
    CONCAT('court:', sm.court_id, '|date:', sm.slot_date, '|time:', TIME_FORMAT(sm.slot_time, '%H:%i')),
    'auto',
    MIN(sm.sender_id),
    MIN(sm.created_at)
FROM slot_messages sm
JOIN courts c ON c.id = sm.court_id
GROUP BY sm.court_id, sm.slot_date, sm.slot_time;

-- Add slot message senders as members
INSERT IGNORE INTO chat_members (group_id, user_id, role)
SELECT g.id, sm.sender_id, 'member'
FROM chat_groups g
JOIN slot_messages sm ON g.description = CONCAT('court:', sm.court_id, '|date:', sm.slot_date, '|time:', TIME_FORMAT(sm.slot_time, '%H:%i'))
WHERE g.type = 'auto'
GROUP BY g.id, sm.sender_id;

-- Copy slot messages
INSERT INTO chat_messages (group_id, sender_id, content, created_at)
SELECT g.id, sm.sender_id, sm.body, sm.created_at
FROM slot_messages sm
JOIN chat_groups g ON g.description = CONCAT('court:', sm.court_id, '|date:', sm.slot_date, '|time:', TIME_FORMAT(sm.slot_time, '%H:%i'))
WHERE g.type = 'auto'
ORDER BY sm.created_at ASC;
