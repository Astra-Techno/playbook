# KoCourt Partner — architecture audit

**Date:** 31 October 2026  
**Scope:** Phase 0. Source inspected in this workspace. Live database and production config were not connected.  
**Rule:** No application or schema changes in this phase.

## What exists

The owner product is already a Flutter app, not a greenfield project.

| Piece | Path | Evidence |
|---|---|---|
| Owner app | `kocourt_owner/` | `pubspec.yaml` name `kocourt_owner`, description "KoCourt Owner - Venue Management App", version `1.0.0+1` |
| Customer app | `kocourt_flutter/` | Separate Flutter app, same shared package and API |
| Shared Dart package | `kocourt_shared/` | Auth, API client, theme, payments |
| Backend | `backend/` | Single PHP front controller `backend/index.php`, MySQL via `backend/config/database.php` |

There is no `partner` API namespace. Owner and customer apps call the same routes (`/courts`, `/bookings`, `/sub-courts`, and so on).

## Flutter stack (do not replace)

Verified in `kocourt_owner/pubspec.yaml` and `kocourt_owner/lib/main.dart`:

- Flutter SDK constraint `^3.12.2`
- State: `provider` (`AuthProvider`, `VenueProvider`, `ToastProvider`, `NotificationsProvider`)
- Routing: `go_router` in `kocourt_owner/lib/core/router.dart`
- HTTP: `dio` through `kocourt_shared` `Api()`
- Session: `shared_preferences` (`token`, `user`) in `kocourt_shared/lib/providers/auth_provider.dart`
- Payments SDK: `flutter_cashfree_pg_sdk` (present; owner screens do not start a customer checkout)
- Theme: `AppTheme.theme` from shared package. Primary color is `#E23D28` (`kocourt_shared/lib/core/theme.dart`), not the plan green `#1A5C35`

App title in `MaterialApp.router` is **KoCourt Owner**.

## Navigation that ships today

`OwnerAppShell` (`kocourt_owner/lib/screens/app_shell.dart`) uses an `IndexedStack` with five tabs:

1. Venues — `OwnerDashboardScreen`
2. Bookings — `OwnerBookingsScreen`
3. Earnings — `OwnerEarningsScreen`
4. Chat — `ChatThreadsScreen` (legacy `/messages` threads)
5. Profile — `OwnerProfileScreen`

There is no persistent selected venue. Venue, calendar, spaces, staff, pricing, plans, blocks, and earnings are pushed routes with a `courtId` (`kocourt_owner/lib/core/router.dart`).

Auth redirect: logged-out users go to `/login`, except `/refund-policy` and `/contact`. `/admin` requires `auth.isAdmin`.

## Backend shape

- One `index.php` router. Controllers under `backend/src/Controllers/`.
- Models: `Booking`, `Court`, `User`, `Plan`, `Subscription`.
- Auth: Bearer `users.auth_token`. Roles in code comments are `admin` and `user`. Venue ownership is `courts.owner_id`. Staff is `court_staff`.
- `Auth::requireOwner()` is an alias of `Auth::require()`. Any logged-in user passes it. Ownership is checked inside some controllers, not at the gate (`backend/src/Auth.php`).
- Schema is created two ways: numbered files in `backend/migrations/` (001–019) and runtime `CREATE TABLE` / `ALTER TABLE` inside controllers and `backend/config/database.php`. A live database can therefore differ from the migration files.
- Timezone used in cancellation is `Asia/Kolkata` (`BookingController::cancel`).

## Booking authority (current)

`Booking::isSlotAvailable` (`backend/src/Models/Booking.php`) is the shared check for customer creates, walk-ins, and recurring creates.

- Overlap is half-open: `start_time < requested_end AND end_time > requested_start`.
- Confirmed bookings only. Pending rows do not block a slot.
- `booking_mode` values enforced in `SubCourtController` are `exclusive` and `shared`. Anything else is stored as `exclusive`.
- `shared` compares `COUNT(*)` of overlapping confirmed bookings to `capacity`. There is no quantity column. One booking consumes one unit.
- Blocks: one-off `blocked_slots`, plus `repeat_annually` templates. A facility check also sees venue-wide blocks (`sub_court_id IS NULL`).
- The check and the insert are not in one transaction and do not lock the facility. Two concurrent confirms can both pass the check.
- `Booking::create` always inserts `status='confirmed'` and `payment_status='paid'`.

Customer paid checkout is a separate path (`PaymentController`, `CommerceCheckout`) and is outside this Partner phase. It must keep working.

## What this audit did not verify

- Production or staging MySQL contents, indexes, and enum drift versus migrations.
- Cashfree or Razorpay credentials, webhook registration, or a live payment.
- Android or iOS build output.
- Whether `GET /courts?owner_id=` is intentionally public. The controller passes the query `owner_id` into `Court::read` (`CourtController::index`), unlike bookings, which ignore the client id and use the token.
