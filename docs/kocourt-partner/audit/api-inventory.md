# KoCourt Partner — API inventory

**Date:** 31 October 2026  
**Source:** `backend/index.php` and the controllers it calls.  
**Paths** are the first segment after `/api` is stripped. Example: `GET /api/bookings` is `GET /bookings`.

There is no `/partner` prefix. Do not add one until a phase is approved. Reuse these routes.

Auth shorthand: **token** = `Auth::require()` (401 if missing). **owner-checked** = controller compares `courts.owner_id` to the token user. **admin** = `users.role = admin`. **public** = no `Auth::require` on that branch.

`Auth::requireOwner()` does not check ownership. It only checks that a token exists.

## Identity

| Method | Path | Auth | Notes |
|---|---|---|---|
| POST | `/auth/send-otp` | public | OTP send |
| POST | `/auth/check-phone` | public | |
| POST | `/auth/verify-otp` | public | Returns token |
| GET | `/auth/profile` | token | |
| PUT | `/auth/profile` | token | |
| POST | `/auth/fcm-token` | token | |
| POST | `/upload` | see handler | Used by venue photo upload |

## Venues (`courts`)

| Method | Path | Auth | Notes |
|---|---|---|---|
| GET | `/courts` | public | `owner_id` query is passed through. Not rewritten from the token |
| GET | `/courts/:id` | public | |
| GET | `/courts/:id/calendar` | public | |
| GET | `/courts/:id/regulars` | public | Returns player phone numbers for confirmed bookers in 90 days |
| GET | `/courts/available-at` | public | |
| GET | `/courts/claims` | token | Admin queue is used by `AdminScreen` |
| POST | `/courts` | token | `owner_id` taken from token |
| POST | `/courts/claim` | token | |
| PUT | `/courts/:id` | token | Owner-checked |
| PUT | `/courts/:id/verify` | admin | |
| PUT | `/courts/:id/featured` | admin | |
| PUT | `/courts/claims/:id/approve` | admin | |
| PUT | `/courts/claims/:id/reject` | admin | |
| DELETE | `/courts/:id` | token | Hard delete. Bookings FK is `ON DELETE CASCADE` in migration 005 |

## Facilities (`sub-courts`)

| Method | Path | Auth | Notes |
|---|---|---|---|
| GET | `/sub-courts?court_id=` | public | |
| GET | `/sub-courts/:id` | public | |
| POST | `/sub-courts` | token | Owner-checked. `booking_mode` allowed: `exclusive`, `shared` |
| PUT | `/sub-courts/:id` | token | Owner-checked |
| DELETE | `/sub-courts/:id` | token | Owner-checked. No future-booking guard |

## Pricing, blocks, staff

| Method | Path | Auth | Notes |
|---|---|---|---|
| GET | `/pricing-rules` | public | |
| GET | `/pricing-rules/calculate` | public | |
| GET | `/pricing-rules/calculate-day` | public | |
| POST | `/pricing-rules` | token | `requireOwner` only; confirm owner check inside `PricingController` before relying on it |
| DELETE | `/pricing-rules/:id` | token | |
| GET | `/blocked-slots` | public | |
| POST | `/blocked-slots` | token | `block_kind`: maintenance, holiday, private_event, tournament, coaching, other |
| DELETE | `/blocked-slots/:id` | token | |
| GET | `/court-staff?court_id=` | token | Owner-checked |
| GET | `/court-staff/my-courts` | token | Staff’s venues. Owner dashboard does not call this |
| POST | `/court-staff` | token | Owner-checked. Body phone or user id. Role `manager` or `viewer` |
| DELETE | `/court-staff/:id` | token | |

## Bookings

| Method | Path | Auth | Notes |
|---|---|---|---|
| GET | `/bookings?user_id=` | token user | Query id ignored. Returns the token user’s bookings |
| GET | `/bookings?court_id=&date=` | reads token then queries | Used by owner calendar. Returns confirmed rows for that date. `index()` dereferences `Auth::user()` before branching, so a missing token fatals on PHP 8 rather than returning 401 |
| GET | `/bookings?owner_id=` | token user | Query id ignored. Bookings for courts owned by the token user |
| GET | `/bookings?staff_id=` | token user | Bookings for `court_staff` courts |
| GET | `/bookings/:id` | token | Booking owner, court owner, or admin. Staff manager is not included |
| GET | `/bookings/busy-days` | public | Response key is `busy_days`. Owner calendar reads `days` |
| POST | `/bookings` | token, or walk-in | Walk-in = non-empty `guest_name`, allowed for court owner, admin, or staff `manager`. Inserts confirmed + paid. Slot check is not locked |
| POST | `/bookings/recurring` | token | Up to 12 weeks. Skips conflicts. Not all-or-nothing |
| DELETE | `/bookings/:id` | token | Cancel. Booking owner, court owner, staff manager, or admin. Refund path via `RefundService` when a commerce snapshot and `payment_id` exist |

Not present: quote, hold, reschedule, check-in, no-show, idempotency key, booking audit log.

## Payments, earnings, plans

| Method | Path | Auth | Notes |
|---|---|---|---|
| POST | `/payments/quote` | see controller | Customer checkout |
| GET | `/payments/config` | see controller | |
| POST | `/payments/create-order` | see controller | Cashfree fields (`cf_order_id`) |
| POST | `/payments/verify` | see controller | Uses `FOR UPDATE` on the payment row |
| GET | `/payments/history` | token | |
| POST | `/payments/refund-webhook` | webhook | |
| GET | `/payments/refunds` | token | |
| GET | `/earnings` | token | Owner earnings |
| GET | `/earnings/venue` | token | |
| GET | `/earnings/ledger` | token | Admin ledger screen |
| GET | `/earnings/export` | token | |
| POST | `/payouts` | admin | Also `POST /admin/payouts` creates the `payouts` table if missing |
| GET/POST | `/vendor/profile` | see `VendorController` | Bank and tax profile |
| GET/POST/DELETE | `/plans` | mixed | Court membership plans |
| GET | `/subscriptions` | token | |
| GET | `/subscriptions/members` | token | |
| POST | `/subscriptions` | token | |
| POST | `/subscriptions/renew` | token | |
| PUT | `/subscriptions/:id/cancel` | token | |
| GET | `/analytics` | token | Owner analytics. No owner screen calls it |

`backend/config/razorpay.php` exists beside `backend/config/cashfree.php`. Active checkout code paths inspected use Cashfree order ids. Which provider is live in production was not verified.

## Notifications and admin

| Method | Path | Auth | Notes |
|---|---|---|---|
| GET | `/notifications/list` | token | Owner notifications screen |
| PUT | `/notifications/read-all` | token | |
| PUT | `/notifications/:id/read` | token | |
| GET | `/user-notifications` | token | Second notification table path. Runtime `CREATE TABLE` |
| PUT | `/user-notifications/:id/read` | token | |
| GET | `/admin/users` | admin | |
| PUT | `/admin/users/:id/role` | admin | Roles accepted: `user`, `admin` only |
| GET/PUT/DELETE | `/admin/config` | admin | |
| GET | `/admin/demand` | admin | |
| POST | `/admin/builds/trigger` | admin | GitHub Actions. Out of Partner MVP |

## Explicitly absent

No routes for tournaments, event registration, organizer authorization, booking holds, check-in, settlements per booking, or customer directory beyond `/courts/:id/regulars` and `/users/search`.

## Error shape

Handlers return `message` or `error` strings with HTTP status. They do not use the plan’s stable codes (`CAPACITY_CONFLICT`, `HOLD_EXPIRED`, and so on). A slot conflict from `POST /bookings` is HTTP 409 and `"Time slot not available."`.
