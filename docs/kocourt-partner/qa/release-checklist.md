# KoCourt Partner release checklist

**Date:** 3 November 2026  
**Result:** Not ready to release. Nothing was deployed.

This pass ran the unit tests that do not need a database, then a separate local database named `playbook_staging`. It did not open a device or the customer app. Nothing was deployed.

## Unit tests this session

| Suite | Result | Evidence |
|---|---|---|
| Backend `tests/*_test.php` | PASS | 26 files, 0 failed |
| Owner app `flutter test` | PASS | 57 tests, 0 failed |

## Staging rehearsal

Ran `php scripts/staging_rehearsal.php` on 3 November 2026 against local MySQL. The app database `playbook` stayed at schema version 21 with its existing 11 bookings. A separate database `playbook_staging` reached schema version 36.

| Check | Status | Evidence |
|---|---|---|
| Migrations `019` through `032` on a separate database | PASS | `playbook_staging` schema version 36. `collection_method`, `attendance`, `booking_holds`, `tournaments`, `coaching_sessions`, `equipment_items`, `equipment_rentals`, and `user_notifications.event_key` are present |
| One booking on that database occupies the court | PASS | Booking 1 for 20 December 2026, 06:00–07:00. A second request for the same court and time was refused |
| `playbook` left unchanged | PASS | Still schema version 21, 11 bookings |
| Backup and restore | NOT RUN | No dump was taken and no restore was tried |
| Customer app against staging | NOT RUN | The booking used `Booking::create` and `Booking::isSlotAvailable`, the same model the API uses. The Flutter customer app was not started |

`bookings.sub_court_id` is not part of the version-36 stamp. The rehearsal created it the same way the API does, by constructing `SubCourtController`, which adds the facility and guest columns on first use. A database that only runs `migrate()` still lacks those columns until that request.

## Section 18

| Item | Status | Evidence |
|---|---|---|
| Phase 0 audit approved | PASS | `progress/DECISIONS.md` records approval on 31 October 2026 |
| Auth and permissions for owner and staff | NOT RUN | `staff_access_test.php` and `router_test.dart` passed as unit tests. Two signed-in accounts were not tried against a running API |
| Venue and facility navigation | NOT RUN | Space-field unit tests passed. The venue screens were not opened in a running app |
| Existing customer bookings still work | NOT RUN | The customer app was not started in this pass |
| Facility capacity and booking mode | NOT RUN | The shared slot rules have unit tests. Two database connections were not raced |
| Pricing and availability consistent across apps | NOT RUN | `schedule_rules_test.php` passed. The customer app and the owner calendar were not compared on a device |
| Manual bookings, cancellations, and reschedules | NOT RUN | Walk-in and attendance unit tests passed. Those screens were not used in a running app |
| Payment webhooks idempotent and reconciled | NOT RUN | `refund_webhook_replay_test.php` passed with no Cashfree call and no live webhook |
| Refund and payout records | NOT RUN | `settlement_math_test.php` passed. No live refund or payout was sent |
| Tournament registration and allocation | NOT RUN | Tournament unit tests passed. The routes were not called against a live database |
| Legacy bookings handled safely | NOT RUN | Null `sub_court_id` rows were not queried on a live database |
| Migration rehearsal and backup or restore | NOT RUN | `playbook_staging` reached schema version 36 and kept one booking. `playbook` stayed at version 21 with 11 bookings. No backup or restore was tried |
| Concurrency tests | NOT RUN | `slot_lock_test.php` and `payment_hold_test.php` passed without two live connections |
| Security and IDOR tests | NOT RUN | No second account requested another venue’s money or staff list on a running API |
| Crash and error monitoring | NOT RUN | No monitoring tool was configured in this pass |
| Android release build | NOT RUN | No release build was made |
| iOS release build | NOT RUN | No release build was made |
| Owner onboarding and support process | NOT RUN | Login and profile unit coverage exists. A new owner was not walked through setup |
| Pilot venue feedback | NOT RUN | No Sivakasi pilot was reviewed |
| Rollback and incident runbook | NOT RUN | No runbook file was written |

## Blocking before a release

- Apply migrations `019` through `032` on a staging copy and rehearse backup and restore.
- Race the slot lock and a tournament seat with two database connections.
- Open the owner app and the customer app against that staging database and book the same court.
- Make an Android release build. Add an iOS build if that store is in this launch.
- Leave live Cashfree entry checkout closed until that work is approved.
- Leave package credits out. Plans stay peak-hour memberships.

No item in this table is FAIL. The release stays unsigned because the operational checks were not run.
