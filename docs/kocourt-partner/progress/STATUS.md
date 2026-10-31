# KoCourt Partner development status

## Current phase

Phase 2 — Venue and facility forms. The venue gallery, listing labels, and staff edit gate are in review.

## Current task

Venue edit loads the existing photo gallery (`GET` / `POST` / `DELETE /court-photos`). Listing and verification are labels only. Staff can open a venue and its spaces, and cannot edit, delete, or change pricing, plans, blocks, staff, or earnings. Deleting a venue is refused while an upcoming booking exists. No new columns.

## Completed with evidence

- Owner app, shared package, and PHP API inventoried.
- Audit files in `docs/kocourt-partner/audit/`.
- Master plan copied to `docs/kocourt-partner/MASTER_DEVELOPMENT_PLAN.md`.
- P1-T1: Venues tab loads `GET /courts` and `GET /court-staff/my-courts`, labels Owner vs Staff, and shows a retry when either request fails. Merge rules are covered by `kocourt_owner/test/venue_access_test.dart`.
- P1-T2: Bookings, Earnings, Chat, and Profile keep a loading spinner, an error with Try again, and a separate empty state. A failed refresh does not replace existing rows with an empty list. Venues already had this from P1-T1.
- P1-T3: `ownerRouteRedirect` sends signed-out users to `/login`, leaves a signed-in owner on `/`, and sends a non-admin away from `/admin`. Covered by `kocourt_owner/test/router_test.dart`.
- Phase 2 space form: `POST` and `PUT /sub-courts` receive capacity and `booking_mode`. The detail screen reads the `space` payload. Delete returns 409 when a future booking remains.
- Phase 2 venue slice: gallery uses `court_photos`. The venue screen shows whether players can see it and whether KoCourt has verified it. Owner-only actions stay hidden unless `owner_id` matches the signed-in user. `DELETE /courts/:id` returns 409 while an upcoming booking remains.

## Partial

- Live MySQL was not queried. Schema notes are from migrations and runtime DDL.
- Payment provider in production was not called.
- `flutter analyze` and backend tests were not run in this phase.

## Blocked / missing access

- No staging database connection in this session.
- No production credentials. Do not paste them into chat.

## Tests run

- `flutter test test/venue_access_test.dart` in `kocourt_owner`: 2 passed.
- `flutter test test/tab_phase_test.dart` in `kocourt_owner`: 4 passed.
- `flutter test test/router_test.dart` in `kocourt_owner`: 4 passed.
- `flutter test test/space_fields_test.dart` in `kocourt_owner`: 4 passed.
- `flutter test test/venue_listing_test.dart` in `kocourt_owner`: 3 passed.
- `flutter analyze` on the space list, form, and detail screens, and on the venue list, detail, and edit screens: no issues.
- The space form and venue gallery were not exercised in a running app.

## Schema changes

- None. Capacity and booking mode already exist on `sub_courts`.

## Customer app compatibility

- Customer venue detail already loads `GET /sub-courts` and `GET /court-photos`. Availability still uses the shared `booking_mode` check. Not retested in a running customer app.
- Owners still cannot publish or verify themselves. Those remain admin actions.

## Next approved task

- Phase 2 form work for spaces and venues is in review. Phase 3 (pricing, hours, blocks, calendar, walk-in times) has not started.

## Decisions requiring owner approval

See `progress/DECISIONS.md`.
