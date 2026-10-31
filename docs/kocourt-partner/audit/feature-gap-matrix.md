# KoCourt Partner — feature gap matrix

**Date:** 31 October 2026  
**Statuses:** Implemented, Partial, Missing, Needs verification.  
**Release tags** match the master plan: R1 venue operations, R2 events and finance, R3 growth, R4 later.

| Feature | Release | Status | Evidence | Gap to close |
|---|---|---|---|---|
| OTP login and session restore | R1 | Implemented | `AuthProvider`, `/login` | Expired-token handling is whatever Dio does today. Not separately tested |
| Owner vs admin route guard | R1 | Implemented | Router redirects non-admin away from `/admin` | `requireOwner` on the API is not an owner check |
| Venue list, create, edit, claim | R1 | Implemented | Dashboard, `EditVenueScreen`, `ClaimVenueSheet` | Staff venues are not on the dashboard (`GET /court-staff/my-courts` unused) |
| Venue photos | R1 | Partial | Upload on edit form | No gallery reorder. `court-photos` API unused by this screen |
| Facility list | R1 | Partial | `SpacesScreen` | Create sends name only. Capacity and `booking_mode` stay at server defaults (`1`, `exclusive`) |
| Facility booking mode | R1 | Partial | API accepts `exclusive` and `shared` | No owner UI. Plan names must not be written into `booking_mode` |
| Shared capacity enforcement | R1 | Partial | `Booking::isSlotAvailable` counts booking rows | No per-booking quantity. Concurrent requests are not locked. Needs verification under load |
| Pricing rules | R1 | Partial | `PricingScreen`, calculator in `BookingController` | Venue screen, not a per-facility editor. Overlapping rules resolve by priority then id |
| Operating hours | R1 | Partial | Venue form fields | No facility-level hours table. Overnight hours not specified in the calculator |
| Blocks and annual repeat | R1 | Partial | `BlockSlotsScreen`, migration 017 | Block create does not surface conflicting bookings. UI copy and API can diverge |
| Day calendar | R1 | Partial | Month grid + day list | Not a facility timeline. Busy dots read the wrong JSON key (`days` vs `busy_days`) |
| Week calendar | R1 | Missing | — | |
| Owner booking list | R1 | Implemented | Bookings tab | No filters for facility, source, or payment |
| Walk-in booking | R1 | Missing in UI | `WalkInSheet` is never opened. API path exists | Wire-up must send full datetimes, not `HH:mm`, and must not mark cash as paid without a recorded method |
| Guest fields | R1 | Partial | Columns and API | `user_id = 0` vs FK needs verification |
| Check-in, no-show, reschedule | R1 | Missing | Status enum has three values | Do not extend the enum until approved |
| Cancel from owner app | R1 | Missing in UI | `DELETE /bookings/:id` works for owner and manager | Screen and refund display |
| Idempotent booking create | R1 | Missing | No idempotency key on `POST /bookings` | |
| Availability lock | R1 | Missing | Check then insert, no transaction | Required before calling the engine concurrency-safe |
| Legacy null `sub_court_id` | R1 | Implemented on read | Queries still return those rows | Do not backfill facilities automatically |
| Dashboard KPIs | R2 | Missing | Venues tab is a list | `GET /analytics` exists and is unused |
| Earnings view | R2 | Partial | Earnings tab and per-venue screen | Gross vs collected vs commission vs settled is not documented in the UI. Formula needs a finance pass |
| Payout record | R2 | Partial | Admin `POST /payouts` | Not booking-level settlement. Owner must not trigger live payouts from a task |
| Vendor / Cashfree profile | R2 | Partial | `PayoutSettingsScreen` | Masking of bank and tax fields needs verification in `VendorController` responses |
| Refund lifecycle | R2 | Partial | Cancel enqueues `RefundService` | No owner refund tracker screen |
| Webhook idempotency | R2 | Partial | Payment verify uses `FOR UPDATE`. Refund gateway sends an idempotency header | Replay tests not present. No backend test suite |
| Tournaments / organizers | R2 | Missing | No tables, no screens | Design with the customer plan before any migration. `block_kind=tournament` is only a closure label |
| Membership plans | R3 | Partial | `plans`, `user_subscriptions`, peak-hour gate | This is peak access, not credits. Do not add a usage ledger until semantics are signed off |
| Customer directory | R3 | Missing | `/courts/:id/regulars` returns phones and is unused | Privacy review before any directory |
| Staff invite | R3 | Partial | `StaffScreen`, roles `manager` and `viewer` | Viewer is not enforced on every read. No receptionist, coach, or organizer |
| Reports export | R3 | Missing in UI | `GET /earnings/export` | |
| Coaching / equipment | R4 | Missing | — | Stay out of R1 |
| Chat | Not Partner MVP | Implemented | Legacy `/messages` | Do not rebuild. Do not block R1 on chat |
| Notifications | R1 | Implemented | `/notifications` | Event types are ad hoc inserts, not an outbox |
| Tests | All | Partial | `kocourt_owner/test/router_test.dart` only | No booking, permission, or concurrency tests. Backend test folder is empty |

## Already reused (do not rebuild)

- `kocourt_owner` app, Provider, go_router, Dio, shared theme and `Api`.
- `courts` / `sub_courts` / `bookings` / `pricing_rules` / `blocked_slots` / `court_staff` / `plans`.
- One slot check for customer and owner creates.
- Cashfree-oriented payment and refund code for later finance work.

## First engineering risks that are not “missing screens”

1. Slot check is racy.
2. Owner calendar busy-day key is wrong.
3. Facility delete does not protect future bookings, and the dialog claims bookings are removed.
4. Walk-in sheet is dead code and its payload would not store the selected date.
5. `Booking::create` marks every direct insert paid and confirmed, including a walk-in.
