# KoCourt Partner development status

## Current phase

Phase 4 — Booking detail, week summary, cancel, and move. This slice is in review.

## Current task

A booking opens its detail. Cancel uses `DELETE /bookings/:id`. Move uses `PUT /bookings/:id` and keeps the stored price. The week control lists seven days from `GET /courts/:id/calendar?view=week`. No new columns or statuses.

## Completed with evidence

- Owner app, shared package, and PHP API inventoried.
- Audit files in `docs/kocourt-partner/audit/`.
- Master plan copied to `docs/kocourt-partner/MASTER_DEVELOPMENT_PLAN.md`.
- P1-T1: Venues tab loads `GET /courts` and `GET /court-staff/my-courts`, labels Owner vs Staff, and shows a retry when either request fails. Merge rules are covered by `kocourt_owner/test/venue_access_test.dart`.
- P1-T2: Bookings, Earnings, Chat, and Profile keep a loading spinner, an error with Try again, and a separate empty state. A failed refresh does not replace existing rows with an empty list. Venues already had this from P1-T1.
- P1-T3: `ownerRouteRedirect` sends signed-out users to `/login`, leaves a signed-in owner on `/`, and sends a non-admin away from `/admin`. Covered by `kocourt_owner/test/router_test.dart`.
- Phase 2 space form: `POST` and `PUT /sub-courts` receive capacity and `booking_mode`. The detail screen reads the `space` payload. Delete returns 409 when a future booking remains.
- Phase 2 venue slice: gallery uses `court_photos`. The venue screen shows whether players can see it and whether KoCourt has verified it. Owner-only actions stay hidden unless `owner_id` matches the signed-in user. `DELETE /courts/:id` returns 409 while an upcoming booking remains.
- Phase 3 pricing and closures: `ScheduleRules` is the shared quote and overlap helper. Facility rules win over venue rules. Higher priority, then newer id. A range is summed in 30-minute steps. A venue block covers every facility. A facility block covers only that facility. Shared mode still counts booking rows.
- Phase 4 calendar and walk-in: month dots use `busy_days`. The day list shows bookings and closures from the calendar API. Walk-ins post `guest_name` plus `start_time` and `end_time`. `SlotLock` wraps direct create, recurring create, and payment fulfilment.
- Phase 4 detail: week counts come from the calendar payload. Cancel and move are limited to a future confirmed booking. Move checks the slot while ignoring the booking itself, then updates only the times.

## Partial

- Live MySQL was not queried. Schema notes are from migrations and runtime DDL.
- Payment provider in production was not called.
- `flutter analyze` and backend tests were not run against a live database. The schedule rules were run without MySQL.

## Blocked / missing access

- No staging database connection in this session.
- No production credentials. Do not paste them into chat.

## Tests run

- `flutter test test/venue_access_test.dart` in `kocourt_owner`: 2 passed.
- `flutter test test/tab_phase_test.dart` in `kocourt_owner`: 4 passed.
- `flutter test test/router_test.dart` in `kocourt_owner`: 4 passed.
- `flutter test test/space_fields_test.dart` in `kocourt_owner`: 4 passed.
- `flutter test test/venue_listing_test.dart` in `kocourt_owner`: 3 passed.
- `flutter test test/schedule_fields_test.dart` in `kocourt_owner`: 3 passed.
- `php tests/schedule_rules_test.php` in `backend`: all passed.
- `flutter test test/slot_block_test.dart` in `kocourt_flutter`: 2 passed.
- `php tests/slot_lock_test.php` in `backend`: all passed.
- `flutter test test/walk_in_fields_test.dart` in `kocourt_owner`: 7 passed.
- `flutter analyze` on the calendar, booking detail, and bookings list: no issues.
- Cancel, move, and the week list were not exercised in a running app.

## Schema changes

- None in this slice. Facility open and close times are still the venue `open_time` and `close_time`. A per-space hours column was not added.

## Customer app compatibility

- Customer venue detail already loads `GET /sub-courts` and `GET /court-photos`. Availability still uses the shared `booking_mode` check. Not retested in a running customer app.
- The player slot grid now marks an hour closed when the block row overlaps it, including a yearly block placed on that date by the server. When closing time is later than opening time, the grid follows those venue hours.
- The player slot grid treats a confirmed booking as covering an hour when its start and end overlap that hour, using the same half-open check as a closure.
- The price shown before payment is still the venue hourly rate. `POST /bookings` stores the rule price. Payment checkout still uses the commerce snapshot taken when the order was created.
- Owners still cannot publish or verify themselves. Those remain admin actions.

## Next approved task

- Check-in, no-show, and payment holds are still absent. They need statuses or tables that were not added. A walk-in is stored as confirmed, and the existing create path records it as paid. Phase 5 has not started.

## Decisions requiring owner approval

See `progress/DECISIONS.md`.
