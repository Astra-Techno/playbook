# KoCourt Partner — database inventory

**Date:** 31 October 2026  
**Evidence:** `backend/migrations/*.sql`, runtime DDL in `backend/config/database.php` and controllers.  
**Not evidence:** a live `SHOW CREATE TABLE`. Production may have drifted. Do not run new DDL from this document.

## How schema is applied

1. Numbered SQL files `001`–`019`, applied by `backend/scripts/migrate.php`.
2. `Database` connection bootstrap runs further `CREATE` / `ALTER` and swallows duplicate-column errors.
3. Several controllers call `CREATE TABLE IF NOT EXISTS` or `ALTER TABLE` on first request (`SubCourtController`, `StaffController`, `CourtController` claims, `index.php` payouts, notifications, booking_players).

Treat migration files as the baseline and runtime alters as columns that appear only after that code has run.

## Tables the Partner plan cares about

### `users` — migration 001, plus alters

Identity. `role` used by `Auth::requireAdmin`. `auth_token` added in `database.php`. Phone unique index is attempted at bootstrap. OTP table `otp_tokens` is referenced by auth code; confirm its migration before changing login.

### `courts` — migration 002

Venue table. Keep the name. Columns in migration 002 include `owner_id`, `name`, `type` (later widened to `VARCHAR(50)`), `description`, `location`, `lat`, `lng`, `hourly_rate`, `open_time`, `close_time`, morning and evening peak times, `peak_members_only`, `claim_status`, claim proof and rejection text.

`is_verified` from the external SQL snapshot was **not** found in migration 002. Verification in this code is admin `PUT /courts/:id/verify` and `claim_status`. Confirm the live column before the app reads `is_verified`.

`image_url` is `TEXT` after migration 016.

### `sub_courts` — created in `database.php` and `SubCourtController`, not a numbered migration

Facility table. Base columns: `court_id`, `name`, `description`, `hourly_rate`, `sort_order`.

Added on controller boot if missing:

- `image_url`
- `capacity` INT default 1
- `booking_mode` VARCHAR(20) default `exclusive`
- `peak_members_override` TINYINT NULL (also migration 017)

Allowed `booking_mode` values in PHP: `exclusive`, `shared`. The plan names `exclusive_slot`, `shared_capacity`, `session_class`, `membership_access`, and `package_credit` are not stored.

No foreign key from `sub_courts.court_id` in the `CREATE TABLE` inside `SubCourtController` (index `idx_court` only).

### `bookings` — migration 005, plus runtime columns

| Column | Source | Notes |
|---|---|---|
| `user_id`, `court_id`, `start_time`, `end_time` | 005 | `user_id` is `NOT NULL` with FK to `users`. Walk-ins set `user_id = 0`. That insert fails if user 0 does not exist, or succeeds only if a zero id is present. **Needs a staging check** |
| `type` | 005 | `hourly` or `subscription` |
| `total_price` | 005 | |
| `status` | 005 | `pending`, `confirmed`, `cancelled`. Default `confirmed`. No checked-in, completed, no-show, or held |
| `payment_status` | 005 | `pending`, `paid`, `failed`. `Booking::create` forces `paid` |
| `sub_court_id`, `guest_name`, `guest_phone`, `notes` | `SubCourtController::ensureTable` | Nullable. Legacy rows can have null `sub_court_id` |
| `commerce_snapshot`, `payment_id` | used by `Booking` model and cancel/refund | Confirm they exist on the live table. They are not in migration 005 |

Overlap index on `(court_id, sub_court_id, start_time, end_time, status)` was not found in the migrations read. `blocked_slots` has `idx_court_date (court_id, start_time)`.

### `pricing_rules`

Used by `PricingController` and `BookingController::calculateBookingPrice`. Scope: `court_id`, optional `sub_court_id`, `day_type` (`all`, `weekday`, `weekend`), `start_hour`, `end_hour`, `price`, `valid_from`, `valid_to`, `priority`. Precedence in the booking calculator: highest `priority`, then newest `id`, facility rule before venue rule, else base hourly rate. Price is summed in 30-minute steps (`hourly / 2`).

The numbered migration for this table was not in `001`–`019`. It is created from PHP. Confirm on staging before editing.

### `blocked_slots`

Created in `database.php`. Migration 017 adds `block_kind` (default `other`) and `repeat_annually`. Controller allows kinds: `maintenance`, `holiday`, `private_event`, `tournament`, `coaching`, `other`.

### `court_staff`

Created in `StaffController::ensureTable`. Columns: `court_id`, `user_id`, `added_by`, `role` enum `manager`|`viewer`, unique `(court_id, user_id)`. Not the plan roles (receptionist, coach, organizer).

### `plans` and `user_subscriptions`

Migration 003: `plans` are per `court_id`, with `name`, `duration_days`, `price`. `Plan` model also adds `sub_court_id` at runtime.

Migration 004: `user_subscriptions`. `SubscriptionController` adds `cancelled_at`. Booking peak-hour logic treats an active subscription as the right to book morning or evening peak when `coversSlot` matches `slot_type`.

This is a **peak-access membership**, not a credit ledger. Do not map it to `package_credit` without a separate decision.

### Payments and payouts

`payments` created in `database.php` (Cashfree-oriented columns used by `PaymentController`). Refund tables are used by `RefundService` (`refund_requests`, `booking_refunds`, webhook events). Idempotency exists on the refund gateway request (`x-idempotency-key`), not on `POST /bookings`.

`payouts` is created lazily in `index.php` (`owner_id`, `amount`, `note`, `recorded_by`). It is not a per-booking settlement ledger. `vendor_profiles` is created in `database.php` and holds payout onboarding fields. Do not log or document sample rows.

### Other tables present and out of Partner MVP

`reviews`, `favorites`, `posts`, `post_likes`, `post_comments`, `places`, `service_requests`, `api_quota`, chat tables in migration 018 (`chat_groups`, `chat_members`, `chat_messages`, `chat_read_status`, `chat_reactions`), `match_requests`, `match_participants`, `booking_players`, `user_notifications`.

No `events`, `tournaments`, `booking_holds`, `resource_reservations`, or organizer tables.

## Compatibility invariants already true in code

- `courts` remains the venue. `sub_courts` remains the facility. The UI calls them spaces.
- Bookings with null `sub_court_id` are still queried by court and date.
- Customer and owner writes share `Booking::isSlotAvailable` and `Booking::create`.
- Historical status values must stay `pending` | `confirmed` | `cancelled` until a migration is approved. Holds, if added, belong in a separate table or a new status only after that approval.

## Staging checks before any migration

1. `SHOW CREATE TABLE bookings` — confirm `user_id` nullability, guest columns, `commerce_snapshot`, `payment_id`, and whether `user_id = 0` rows exist.
2. `SELECT booking_mode, COUNT(*) FROM sub_courts GROUP BY booking_mode`.
3. `SHOW INDEX FROM bookings` and `blocked_slots`.
4. Compare `pricing_rules` columns to `BookingController::calculateBookingPrice`.
5. Row counts for `courts`, `sub_courts`, `bookings` before and after any additive change.
