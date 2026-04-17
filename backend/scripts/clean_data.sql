-- ============================================================
-- PlayBook – Clean / Reset Data Script
-- Run this to wipe all test/demo data while keeping structure.
-- Choose one of the sections below based on what you need.
-- ============================================================

-- ============================================================
-- OPTION A: Full reset — wipe everything (all users, venues,
--           bookings, etc.)  Keeps table structure intact.
--
-- NOTE: Uses DELETE in child→parent order so FK constraints
--       are satisfied without needing FK_CHECKS tricks.
-- ============================================================

DELETE FROM user_notifications;
DELETE FROM match_participants;
DELETE FROM match_requests;
DELETE FROM post_comments;
DELETE FROM post_likes;
DELETE FROM posts;
DELETE FROM service_requests;
DELETE FROM reviews;
DELETE FROM favorites;
DELETE FROM payments;
DELETE FROM user_subscriptions;
DELETE FROM bookings;
DELETE FROM blocked_slots;
DELETE FROM pricing_rules;
DELETE FROM plans;
DELETE FROM court_staff;
DELETE FROM sub_courts;
DELETE FROM courts;
DELETE FROM users;
DELETE FROM api_quota;
-- DELETE FROM places;  -- uncomment to also clear Google Places cache

-- Reset auto-increment counters
ALTER TABLE user_notifications  AUTO_INCREMENT = 1;
ALTER TABLE match_participants   AUTO_INCREMENT = 1;
ALTER TABLE match_requests       AUTO_INCREMENT = 1;
ALTER TABLE post_comments        AUTO_INCREMENT = 1;
ALTER TABLE post_likes           AUTO_INCREMENT = 1;
ALTER TABLE posts                AUTO_INCREMENT = 1;
ALTER TABLE service_requests     AUTO_INCREMENT = 1;
ALTER TABLE reviews              AUTO_INCREMENT = 1;
ALTER TABLE favorites            AUTO_INCREMENT = 1;
ALTER TABLE payments             AUTO_INCREMENT = 1;
ALTER TABLE user_subscriptions   AUTO_INCREMENT = 1;
ALTER TABLE bookings             AUTO_INCREMENT = 1;
ALTER TABLE blocked_slots        AUTO_INCREMENT = 1;
ALTER TABLE pricing_rules        AUTO_INCREMENT = 1;
ALTER TABLE plans                AUTO_INCREMENT = 1;
ALTER TABLE court_staff          AUTO_INCREMENT = 1;
ALTER TABLE sub_courts           AUTO_INCREMENT = 1;
ALTER TABLE courts               AUTO_INCREMENT = 1;
ALTER TABLE users                AUTO_INCREMENT = 1;
ALTER TABLE api_quota            AUTO_INCREMENT = 1;


-- ============================================================
-- OPTION B: Keep owners & venues — only wipe player/booking data
--           (good before going live: keep your own venue setup)
-- ============================================================

/*
DELETE FROM user_notifications WHERE user_id IN (SELECT id FROM users WHERE role IN ('player','user'));
DELETE FROM match_participants  WHERE user_id IN (SELECT id FROM users WHERE role IN ('player','user'));
DELETE FROM match_requests      WHERE user_id IN (SELECT id FROM users WHERE role IN ('player','user'));
DELETE FROM post_comments       WHERE user_id IN (SELECT id FROM users WHERE role IN ('player','user'));
DELETE FROM post_likes          WHERE user_id IN (SELECT id FROM users WHERE role IN ('player','user'));
DELETE FROM posts               WHERE user_id IN (SELECT id FROM users WHERE role IN ('player','user'));
DELETE FROM reviews             WHERE user_id IN (SELECT id FROM users WHERE role IN ('player','user'));
DELETE FROM favorites           WHERE user_id IN (SELECT id FROM users WHERE role IN ('player','user'));
DELETE FROM payments            WHERE booking_id IN (SELECT id FROM bookings WHERE user_id IN (SELECT id FROM users WHERE role IN ('player','user')));
DELETE FROM user_subscriptions  WHERE user_id IN (SELECT id FROM users WHERE role IN ('player','user'));
DELETE FROM bookings            WHERE user_id IN (SELECT id FROM users WHERE role IN ('player','user'));
DELETE FROM users               WHERE role IN ('player','user');
DELETE FROM api_quota;
*/


-- ============================================================
-- OPTION C: Orphan / integrity cleanup
--           Safe to run on live data at any time.
-- ============================================================

/*
DELETE FROM bookings WHERE user_id  NOT IN (SELECT id FROM users)
                       OR court_id  NOT IN (SELECT id FROM courts);

DELETE FROM user_subscriptions
WHERE user_id  NOT IN (SELECT id FROM users)
   OR court_id NOT IN (SELECT id FROM courts)
   OR plan_id  NOT IN (SELECT id FROM plans);

DELETE FROM plans         WHERE court_id NOT IN (SELECT id FROM courts);
DELETE FROM pricing_rules WHERE court_id NOT IN (SELECT id FROM courts);
DELETE FROM pricing_rules WHERE sub_court_id IS NOT NULL AND sub_court_id NOT IN (SELECT id FROM sub_courts);
DELETE FROM blocked_slots WHERE court_id NOT IN (SELECT id FROM courts);
DELETE FROM blocked_slots WHERE sub_court_id IS NOT NULL AND sub_court_id NOT IN (SELECT id FROM sub_courts);
DELETE FROM sub_courts    WHERE court_id  NOT IN (SELECT id FROM courts);
DELETE FROM court_staff   WHERE court_id  NOT IN (SELECT id FROM courts) OR user_id NOT IN (SELECT id FROM users);
DELETE FROM reviews       WHERE court_id  NOT IN (SELECT id FROM courts);
DELETE FROM favorites     WHERE court_id  NOT IN (SELECT id FROM courts);

-- Expired/cancelled subs older than 6 months
DELETE FROM user_subscriptions WHERE status IN ('cancelled','expired') AND end_date < DATE_SUB(CURDATE(), INTERVAL 6 MONTH);

-- Old bookings older than 1 year
-- DELETE FROM bookings WHERE end_time < DATE_SUB(NOW(), INTERVAL 1 YEAR);
*/


-- ============================================================
-- OPTION D: Reset a specific venue only (replace 1 with your id)
-- ============================================================

/*
SET @venue_id = 1;

DELETE FROM bookings           WHERE court_id = @venue_id;
DELETE FROM user_subscriptions WHERE court_id = @venue_id;
DELETE FROM blocked_slots      WHERE court_id = @venue_id;
DELETE FROM pricing_rules      WHERE court_id = @venue_id;
DELETE FROM plans              WHERE court_id = @venue_id;
DELETE FROM sub_courts         WHERE court_id = @venue_id;
DELETE FROM court_staff        WHERE court_id = @venue_id;
DELETE FROM reviews            WHERE court_id = @venue_id;
DELETE FROM favorites          WHERE court_id = @venue_id;
*/
