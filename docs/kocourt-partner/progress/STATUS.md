# KoCourt Partner development status

## Current phase

Phase 8 — Bracket. A finished round sends winners and byes into the next round. One player left wins the category.

## Current task

Saving a result on a Round N match checks the rest of that round. When every match is completed or a bye, those players are paired in match order as Round N+1. An odd player is a bye on the new round. One player left is the champion, shown on the event screen. A manual match labeled Match stays out of this ladder. The next round is written in the same save as the result.

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
- Phase 5 money split: collected is `total_earned` after successful refunds. Paid out is `SUM(payouts.amount)`. Not yet paid out is collected minus paid out and can be negative. `pending_payout` is that same signed remainder. Venue booking prices stay on `total` / `today` / `this_week` / `this_month` and are not treated as collected money. `POST /payouts` stays admin-only. The venue menu stays owner-only.
- Phase 5 venues KPI: the venues list shows collected today and this week only when the owner summary includes `total_earned`. A failed collections refresh keeps the previous figures. An account with no owned venues does not show the card.
- Phase 5 export: `GET /earnings/export` stays owner-scoped. Invalid or reversed dates return 400 before the query runs. The booking-prices screen copies a response only when the first line is the booking-price header.
- Phase 5 pay at venue: walk-ins store `collection_method`. Allowed values are `pay_at_venue`, `cash`, and `external_upi`. An unknown value returns 400. Online bookings leave the column null. Collected payments still come from payment rows.
- Phase 5 webhook replay: `RefundWebhookPlan` decides duplicate, ignore, or reconcile. The webhook route uses that decision. Reconcile calls `process` with reconcile-only, so a provider refund is not created. The signature check rejects a changed body.
- Phase 5 occupancy: `GET /courts/occupancy` returns booked minutes and open minutes for venues the signed-in user owns or is assigned to. The day is Asia/Kolkata unless `date` is sent. Shared bookings in the same hour both count. The venues list shows the line on each venue.
- Arrival: `bookings.attendance` stores `checked_in` or `no_show`. The booking status is unchanged, so a marked booking still occupies the slot. Viewers and the player who booked cannot mark it.
- Payment holds: `booking_holds` reserves each booking slot for 10 minutes at `POST /payments/create-order`. `Booking::isSlotAvailable` counts an unreleased hold whose `expires_at` is still ahead, except the payment being fulfilled. Asia/Kolkata. No Cashfree call was made.
- Phase 6 comparison: `progress/PHASE6_SCHEMA.md`.
- Phase 6 tables: migration `022_tournaments.sql`, applied by schema version 26. `POST /tournaments` and `GET /tournaments` are limited to the signed-in organizer. Covered by `php tests/tournament_draft_test.php`. No live database apply in that session. No Partner screen.
- Phase 6 categories: an organizer adds `tournament_categories` on a draft through `POST /tournaments/:id/categories`. The controller returns 403 for anyone who is not an organizer, and 422 once the event leaves draft. `php tests/tournament_category_test.php` covers the field rules. Those routes were not called against a live database.
- Phase 6 registration: seat rules are in `TournamentRegistration`. A fee uses `tournament_capacity_holds` for 10 minutes. The captain is stored on `tournament_registration_members`. `php tests/tournament_registration_test.php` covers the rules. The routes were not called against a live database.
- Phase 6 publish: `TournamentPublish` decides when a draft may close a venue. `POST /tournaments/:id/publish` writes `blocked_slots.tournament_id` from migration `023`. `php tests/tournament_publish_test.php` covers the rules. The route was not called against a live database. Schema version is 27.
- Phase 6 unpublish: `POST /tournaments/:id/unpublish` sets the event back to `draft` and deletes `blocked_slots` rows for that `tournament_id`. Entries stay. The same test file covers the status rule. The route was not called against a live database.
- Phase 6 entry payment: `TournamentPayment` confirms a pending entry when the paid amount matches the fee and the seat is still available. `php tests/tournament_payment_test.php` covers those rules. Demo checkout and verify were not called against a live database. Live Cashfree was not called.
- Phase 6 Partner screen: Profile opens Events. `event_fields.dart` builds the draft and category bodies. `kocourt_owner/test/event_fields_test.dart` covers them. The screens were not opened in a running app. `GET /tournaments/:id/categories` stays available after publish. Adding a category still requires a draft.
- Phase 6 entries on the event: the detail screen loads `GET /tournaments/:id/categories/:categoryId/registrations` and shows `registrationLine`. The same Flutter test covers that line. The screen was not opened in a running app.
- Phase 6 participant export: `TournamentParticipantExport` writes the CSV, including a door code and a `Checked in` time. `php tests/tournament_participant_export_test.php` passed. The route was not called against a live database. `participantCsv` is covered by the Flutter test. The screen was not opened in a running app.
- Phase 6 check-in: `TournamentCheckIn` allows one arrival on a confirmed entry. `php tests/tournament_check_in_test.php` passed. The route was not called against a live database. Migration `025_registration_check_in.sql` adds `checked_in_at`. Schema version is 29. It was not applied to a live database in this session.
- Phase 6 door code: migration `026_registration_check_in_code.sql` adds `check_in_code`. Schema version is 30. It was not applied to a live database in this session. `POST /tournaments/:id/check-in` uses the same arrival rules. The code format is covered by `php tests/tournament_check_in_test.php`. The route was not called against a live database.
- Phase 6 announcements: `TournamentAnnouncement` checks the message and who should hear it. `php tests/tournament_announcement_test.php` passed. Migration `027_tournament_announcements.sql` adds the event record. Schema version is 31. It was not applied to a live database in this session. Delivery uses `user_notifications`. The route was not called against a live database.
- Phase 6 approval and roster: `tournament_categories.approval` and `tournaments.sponsor_name` are in migration `028_category_approval.sql`. Schema version is 32. It was not applied to a live database. `php tests/tournament_roster_test.php` covers the last seat, doubles, teams, and approve or reject. Payment with approval waits in `pending_approval`. The routes were not called against a live database. Two database connections were not raced.
- Phase 7 members: `MembershipDirectory` builds the owner row without a phone. `php tests/membership_directory_test.php` passed. The Members screen reads `GET /subscriptions/members`. `kocourt_owner/test/member_fields_test.dart` passed. The screen was not opened in a running app. Plans stay peak-hour memberships.
- Phase 7 customers: `CustomerDirectory` keeps name, booking count, and last visit, and drops the phone. The same rule strips the phone from public regulars. `php tests/customer_directory_test.php` passed. The Customers screen reads `GET /courts/:id/customers`. `kocourt_owner/test/customer_fields_test.dart` passed. The screen was not opened in a running app. The route was not called against a live database.
- Phase 7 staff: `StaffAccess` is the manager and viewer matrix, including a refusal when the venue does not match. The customer directory uses that matrix. `POST /court-staff` refuses a role other than manager or viewer, and an omitted role stays manager. `POST /court-staff/:id/role` changes the role for the venue owner. `php tests/staff_access_test.php` passed. The Staff screen reads the `staff` list, invites by phone, and can switch the role. `kocourt_owner/test/staff_fields_test.dart` passed. The screen was not opened in a running app. The role route was not called against a live database. Booking, calendar, and closure checks still read the `court_staff` role column directly.
- Phase 7 report: `VenueReport` adds confirmed booking prices and keeps that total apart from collected payments. A walk-in stays in the price total and out of repeat players. Pending rows stay out of the cancel rate. `php tests/venue_report_test.php` passed. The Report screen reads `GET /courts/:id/report`. `kocourt_owner/test/report_figures_test.dart` passed. The screen was not opened in a running app. The route was not called against a live database. Tournament entry fees are not in this collected total. `GET /analytics` still sums booking prices.
- Phase 8 matches: `TournamentDraw` pairs two confirmed entries and accepts the higher score as the winner. `php tests/tournament_draw_test.php` passed. The event screen lists matches, adds one, and records a score. `kocourt_owner/test/event_fields_test.dart` passed with 7 tests. `flutter analyze` on `event_fields.dart` and `event_detail_screen.dart` reported no issues. The screen was not opened in a running app. The match routes were not called against a live database. Migration 029 was not applied to a live database in this session.
- Phase 8 coaching: `CoachingSession` keeps the instructor as a name, refuses a full class, a duplicate player, a busy court, and a second attendance mark. `php tests/coaching_session_test.php` passed. The Coaching screen reads `GET /courts/:id/coaching`. `kocourt_owner/test/coaching_fields_test.dart` passed. `flutter analyze` on `coaching_fields.dart`, `venue_coaching_screen.dart`, and `venue_detail_screen.dart` reported no issues. The screen was not opened in a running app. The routes were not called against a live database. Migration 030 was not applied to a live database in this session. Creating a class does not insert a booking.
- Phase 8 equipment: `EquipmentRental` keeps a quantity and a deposit, refuses a rental past what is in, and refuses a second return. `php tests/equipment_rental_test.php` passed. The Equipment screen reads `GET /courts/:id/equipment`. `kocourt_owner/test/equipment_fields_test.dart` passed. `flutter analyze` on `equipment_fields.dart`, `venue_equipment_screen.dart`, and `venue_detail_screen.dart` reported no issues. The screen was not opened in a running app. The routes were not called against a live database. Migration 031 was not applied to a live database in this session. A rental does not insert a booking or a payment. Two database connections were not raced.
- Phase 8 bracket: `TournamentDraw::bracket` pairs confirmed entries in id order and gives the last entry a bye. A pending entry stays out. A second bracket is refused. `php tests/tournament_draw_test.php` passed. The event screen posts `POST /tournaments/:id/categories/:categoryId/bracket` when the category has no matches. `kocourt_owner/test/event_fields_test.dart` passed. `flutter analyze` on `event_fields.dart` and `event_detail_screen.dart` reported no issues. The screen was not opened in a running app. The route was not called against a live database. Two database connections were not raced. A bye on Round 1 is stored with round label `Round 1`.
- Phase 8 next round: `TournamentDraw::advance` waits while a Round N match is still scheduled, then pairs winners and byes in match order. A manual Match stays out. One remaining player is the champion. The same player cannot advance twice. `php tests/tournament_draw_test.php` passed. The result save writes the next round before it commits. The event screen reads `champion_registration_id` from `GET .../matches`. `kocourt_owner/test/event_fields_test.dart` passed. `flutter analyze` on `event_fields.dart` and `event_detail_screen.dart` reported no issues. The screen was not opened in a running app. The result route was not called against a live database. Two database connections were not raced. No new migration.

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
- `php tests/settlement_math_test.php` in `backend`: all passed.
- `flutter test test/earnings_figures_test.dart` in `kocourt_owner`: 5 passed.
- `flutter analyze` on the earnings figures, owner earnings screen, venue booking-prices screen, and venues dashboard: no issues.
- Earnings, booking-price, and venues screens were not opened in a running app. No live payment, refund, or webhook was called.
- `php tests/booking_export_query_test.php` in `backend`: all passed.
- `flutter test test/booking_price_export_test.dart` in `kocourt_owner`: 3 passed.
- `flutter analyze` on the booking-price export helper and the booking-prices screen: no issues.
- The Export action was not tapped in a running app.
- `php tests/collection_method_test.php` in `backend`: all passed.
- `flutter test test/walk_in_fields_test.dart` in `kocourt_owner`: 8 passed.
- `flutter analyze` on the walk-in fields, walk-in sheet, and booking detail: no issues.
- The walk-in sheet was not opened in a running app. The migration was not applied to a live database in this session.
- `php tests/refund_webhook_replay_test.php` in `backend`: all passed. No Cashfree request and no live webhook delivery.
- `php tests/occupancy_math_test.php` in `backend`: all passed.
- `flutter test test/occupancy_figures_test.dart` in `kocourt_owner`: 2 passed.
- `flutter analyze` on the occupancy figures and the venues screen: no issues.
- The venues screen was not opened in a running app.
- `php tests/attendance_test.php` in `backend`: all passed.
- `flutter test test/attendance_fields_test.dart` in `kocourt_owner`: 2 passed.
- `flutter analyze` on the attendance labels and the booking detail screen: no issues.
- Check-in and no-show were not tapped in a running app. Migration 020 was not applied to a live database in this session.
- `php tests/payment_hold_test.php` in `backend`: all passed. No Cashfree request. Two live connections were not raced. Migration 021 was not applied to a live database in this session.
- `php tests/tournament_draft_test.php` in `backend`: all passed. Migration 022 was not applied to a live database in this session.
- `php tests/tournament_category_test.php` in `backend`: all passed. Category routes were not called against a live database.
- `php tests/tournament_registration_test.php` in `backend`: all passed. Registration routes were not called against a live database.
- `php tests/tournament_publish_test.php` in `backend`: all passed, including unpublish. Publish and unpublish were not called against a live database. Migration 023 was not applied to a live database in this session.
- `php tests/tournament_payment_test.php` in `backend`: all passed. Entry checkout was not called against a live database. Migration 024 was not applied to a live database in this session. Cashfree was not called.
- `flutter test test/event_fields_test.dart` in `kocourt_owner`: 6 passed. `flutter analyze` on `event_fields.dart` and `event_detail_screen.dart` reported no issues. The screens were not opened in a running app.
- `php tests/tournament_check_in_test.php` in `backend`: all passed. Check-in was not called against a live database. Migration 025 was not applied to a live database in this session.
- `php tests/tournament_announcement_test.php` in `backend`: all passed. Announcements were not called against a live database. Migration 027 was not applied to a live database in this session.
- `php tests/tournament_roster_test.php` in `backend`: all passed. `php tests/tournament_registration_test.php`, `php tests/tournament_payment_test.php`, and `php tests/tournament_category_test.php` passed again. Approval and roster routes were not called against a live database. Migration 028 was not applied to a live database in this session. Two database connections were not raced.
- `flutter test test/event_fields_test.dart` in `kocourt_owner`: 6 passed. `flutter analyze` on the event fields, event detail, and events list reported no issues. The screens were not opened in a running app.
- `flutter test test/member_fields_test.dart` in `kocourt_owner`: 1 passed. `flutter analyze` on `member_fields.dart` and `venue_members_screen.dart` reported no issues. The Members screen was not opened in a running app.
- `php tests/membership_directory_test.php` in `backend`: all passed. The members route was not called against a live database.
- `flutter test test/customer_fields_test.dart` in `kocourt_owner`: 1 passed. `flutter analyze` on `customer_fields.dart`, `venue_customers_screen.dart`, and `venue_detail_screen.dart` reported no issues. The Customers screen was not opened in a running app.
- `php tests/customer_directory_test.php` in `backend`: all passed. The customers route was not called against a live database.
- `flutter test test/staff_fields_test.dart` in `kocourt_owner`: 1 passed. `flutter analyze` on `staff_fields.dart` and `staff_screen.dart` reported no issues. The Staff screen was not opened in a running app.
- `php tests/staff_access_test.php` in `backend`: all passed. The role route was not called against a live database.
- `flutter test test/report_figures_test.dart` in `kocourt_owner`: 1 passed. `flutter analyze` on `report_figures.dart`, `venue_report_screen.dart`, and `venue_detail_screen.dart` reported no issues. The Report screen was not opened in a running app.
- `php tests/venue_report_test.php` in `backend`: all passed. The report route was not called against a live database.
- `flutter test test/event_fields_test.dart` in `kocourt_owner`: 7 passed. `flutter analyze` on `event_fields.dart` and `event_detail_screen.dart` reported no issues. The event screen was not opened in a running app.
- `php tests/tournament_draw_test.php` in `backend`: all passed. The match routes were not called against a live database. Migration 029 was not applied to a live database in this session.
- `php tests/tournament_draw_test.php` in `backend`: all passed, including the first-round bracket and the next round. The bracket and result routes were not called against a live database. Two database connections were not raced. No new migration.
- `flutter test test/event_fields_test.dart` in `kocourt_owner`: 7 passed. `flutter analyze` on `event_fields.dart` and `event_detail_screen.dart` reported no issues. The event screen was not opened in a running app.
- `flutter test test/coaching_fields_test.dart` in `kocourt_owner`: 1 passed. `flutter analyze` on `coaching_fields.dart`, `venue_coaching_screen.dart`, and `venue_detail_screen.dart` reported no issues. The Coaching screen was not opened in a running app.
- `php tests/coaching_session_test.php` in `backend`: all passed. The coaching routes were not called against a live database. Migration 030 was not applied to a live database in this session.
- `php tests/equipment_rental_test.php` in `backend`: all passed. The equipment routes were not called against a live database. Migration 031 was not applied to a live database in this session. Two database connections were not raced.
- `flutter test test/equipment_fields_test.dart` in `kocourt_owner`: 1 passed. `flutter analyze` on `equipment_fields.dart`, `venue_equipment_screen.dart`, and `venue_detail_screen.dart` reported no issues. The Equipment screen was not opened in a running app.
- `php tests/tournament_participant_export_test.php` in `backend`: all passed. The export route was not called against a live database.

## Schema changes

- `bookings.collection_method VARCHAR(32) NULL` is in `backend/migrations/019_booking_collection_method.sql` and in the runtime column check in `backend/config/database.php`. It was not applied to a live database in this session.
- `bookings.attendance VARCHAR(20) NULL` is in `backend/migrations/020_booking_attendance.sql` and in the same runtime column check. It was not applied to a live database in this session.
- `booking_holds` is in `backend/migrations/021_booking_holds.sql` and is created on API connect when the table is missing. It was not applied to a live database in this session.
- The six event tables are in `backend/migrations/022_tournaments.sql`. Schema version is 35. Migration `028_category_approval.sql` adds `tournament_categories.approval` and `tournaments.sponsor_name`. Migration `029_tournament_matches.sql` adds `tournament_matches`, `tournament_match_participants`, and `tournament_results`. Migration `030_coaching_sessions.sql` adds `coaching_sessions`, `coaching_enrollments`, and `blocked_slots.coaching_session_id`. Migration `031_equipment_rentals.sql` adds `equipment_items` and `equipment_rentals`. Migrations 023 through 027 add the court link, the tournament payment type, check-in, the door code, and announcements. None of these were applied to a live database in this session. Facility open and close times are still the venue `open_time` and `close_time`.

## Customer app compatibility

- Customer venue detail already loads `GET /sub-courts` and `GET /court-photos`. Availability still uses the shared `booking_mode` check. Not retested in a running customer app.
- The player slot grid now marks an hour closed when the block row overlaps it, including a yearly block placed on that date by the server. When closing time is later than opening time, the grid follows those venue hours.
- The player slot grid treats a confirmed booking as covering an hour when its start and end overlap that hour, using the same half-open check as a closure.
- The price shown before payment is still the venue hourly rate. `POST /bookings` stores the rule price. Payment checkout still uses the commerce snapshot taken when the order was created.
- Owners still cannot publish or verify themselves. Those remain admin actions.

## Next approved task

- Alerts, localization, accessibility, performance, and release polish are still ahead in Phase 8. Phase 9 release hardening is after that. Package credits stay out until a separate pass. Live Cashfree checkout for an entry fee is not open. The event screen was not clicked through in a running app. `GET /analytics` still sums booking prices and has no owner screen.

## Decisions requiring owner approval

See `progress/DECISIONS.md`.
