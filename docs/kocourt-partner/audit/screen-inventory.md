# KoCourt Partner — screen inventory

**Date:** 31 October 2026  
**App:** `kocourt_owner`  
**Status key:** Implemented = screen exists and calls a real API. Partial = screen exists with a material gap. Missing = no screen.

Plan screen IDs are from `MASTER_DEVELOPMENT_PLAN.md` section 3.3. Names in the app differ (spaces, not facilities; Owner, not Partner).

## Shell and auth

| Plan ID | Plan screen | Actual | Status | Evidence |
|---|---|---|---|---|
| A01 | Splash / session restore | No splash route. `AuthProvider.init` restores `token` and `user` from shared preferences, then `GoRouter` redirects | Partial | `kocourt_shared/lib/providers/auth_provider.dart`, `kocourt_owner/lib/main.dart` |
| A02 | Owner login / OTP | `LoginScreen` at `/login` | Implemented | `kocourt_owner/lib/screens/login/login_screen.dart`, router redirect |
| A03 | Onboarding / profile | `OwnerProfileScreen` is a tab, not a first-run onboarding flow | Partial | `kocourt_owner/lib/screens/profile/owner_profile_screen.dart` |
| A04 | Venue selector | Venue list is the Venues tab. No global “selected venue” and no staff-venue list on that tab | Partial | `owner_dashboard_screen.dart` calls `GET /courts?owner_id=` |
| A05 | Dashboard | Venue cards plus unclaimed “ghost” places. Not a daily operations dashboard (no KPIs, alerts, or quick booking) | Partial | `owner_dashboard_screen.dart` |
| A06 | Notifications | `/notifications` → `NotificationsScreen` (`GET /notifications/list`, mark read) | Implemented | `notifications_screen.dart`. Not a bottom tab |

## Venues and facilities

| Plan ID | Plan screen | Actual | Status | Evidence |
|---|---|---|---|---|
| V01 | Venue list | Venues tab and `/venues` both open `OwnerDashboardScreen` | Implemented | router `/` and `/venues` |
| V02 | Venue form | `/venues/new`, `/venues/:id/edit` → `EditVenueScreen`. Photo upload via `POST /upload` | Implemented | `edit_venue_screen.dart` |
| V03 | Venue photos | Upload on the venue form. No reorder gallery screen | Partial | `edit_venue_screen.dart`. API `court-photos` exists; this screen uses `/upload` |
| F01 | Facility list | `/venues/:id/spaces` → `SpacesScreen`. Add dialog sends name only | Partial | `spaces_screen.dart` |
| F02 | Facility form | No form for sport, capacity, booking mode, or photo. Backend accepts `capacity`, `booking_mode` (`exclusive`\|`shared`), `hourly_rate`, `image_url`, `peak_members_override` | Missing | `SubCourtController::create` vs `SpacesScreen._addSpace` |
| F03 | Facility detail | `/venues/:id/spaces/:spaceId` → `SpaceDetailScreen` loads `GET /sub-courts/:id` | Partial | `space_detail_screen.dart` |
| F04 | Facility pricing | `/venues/:id/pricing` is venue-scoped `PricingScreen`, not per facility | Partial | `pricing_screen.dart` |
| F05 | Hours and closures | Hours are fields on the venue form. Closures are `/venues/:id/block` → `BlockSlotsScreen` | Partial | `edit_venue_screen.dart`, `block_slots_screen.dart` |

`SpacesScreen` delete copy says the space and its bookings will be removed. `SubCourtController::delete` deletes the `sub_courts` row only. It does not look for future bookings.

## Bookings

| Plan ID | Plan screen | Actual | Status | Evidence |
|---|---|---|---|---|
| B01 | Calendar day timeline | `CalendarScreen` is a month grid plus a list of that day’s bookings. No facility columns or time axis | Partial | `calendar_screen.dart` |
| B02 | Calendar week | No week view | Missing | — |
| B03 | Booking list | Bookings tab `OwnerBookingsScreen` loads `GET /bookings?owner_id=` | Implemented | `owner_bookings_screen.dart` |
| B04 | Booking detail | No owner booking-detail route. Chat screen loads `GET /bookings/:id` for a thread | Partial | `chat_screen.dart` |
| B05 | Create booking wizard | `WalkInSheet` posts `POST /bookings` but nothing in `kocourt_owner` calls `WalkInSheet.show` | Missing in the UI | `lib/widgets/sheets/walkin_sheet.dart` (unreferenced) |
| B06 | Reschedule | No screen and no API | Missing | no `reschedule` route in `backend/index.php` |
| B07 | Cancel / refund | No owner cancel button found in owner screens. API `DELETE /bookings/:id` exists and can refund | Missing in the UI | `BookingController::cancel` |
| B08 | Check-in / no-show | No screen and no status | Missing | booking status enum is `pending`, `confirmed`, `cancelled` |

Calendar bug, verified in source: the API returns `busy_days` (`BookingController::busyDays`). The screen reads `res.data['days']`, so busy-day dots stay empty.

Walk-in payload, if the sheet were opened: `start_time` and `end_time` are `HH:mm` only. The API stores those strings as datetimes and ignores the separate `date` field (`WalkInSheet._submit`, `BookingController::create`).

## Money, people, events

| Plan ID | Plan screen | Actual | Status | Evidence |
|---|---|---|---|---|
| P01–P02 | Payment list / detail | No owner payment list. Customer payment history lives in `kocourt_flutter` | Missing | — |
| P03 | Earnings / settlements | Earnings tab and `/venues/:id/earnings`. Admin `/ledger` | Partial | `owner_earnings_screen.dart`, `venue_earnings_screen.dart`, `ledger_screen.dart` |
| — | Payout settings | `/payout-settings` → `PayoutSettingsScreen` (`GET/POST /vendor/profile`) | Implemented | `payout_settings_screen.dart` |
| T01–T07 | Events / tournaments | No owner event screens. `blocked_slots.block_kind` may be `tournament`, which is a closure reason, not an event product | Missing | `BlockController` allowed kinds |
| M01 | Membership plans | `/venues/:id/plans` → `ManagePlansScreen` | Partial | `manage_plans_screen.dart`. Semantics are peak-hour membership, not package credits |
| M02 | Membership holders | `/venues/:id/members` → `VenueMembersScreen` (`GET /subscriptions?court_id=`) | Partial | `venue_members_screen.dart` |
| C01–C02 | Customer directory | No directory. Court regulars API exists (`GET /courts/:id/regulars`) and is not used by an owner screen found here | Missing | `backend/index.php` regulars block |
| S01 | Staff list / invites | `/venues/:id/staff` → `StaffScreen`. Invite by phone of an existing user. Roles sent as the dialog returns them | Partial | `staff_screen.dart`. Server roles are `manager` and `viewer` only |
| S02 | Staff permissions | Role is a single enum. No action matrix | Partial | `StaffController` |
| R01–R02 | Reports / exports | `GET /analytics` and `GET /earnings/export` exist. No owner reports screen calls them | Missing in the UI | `backend/index.php` |
| X01 | Settings | Profile tab, payout settings, legal routes `/refund-policy` and `/contact` | Partial | router |
| X02 | Help / support | `/contact` uses shared `ContactSupportScreen` | Partial | router |
| X03 | Maintenance | Block slots screen | Partial | `block_slots_screen.dart`. Creating a block does not require resolving existing bookings in the UI |
| X04 | Coaching / equipment | Out of current code | Missing | — |

## Admin inside the owner app

`/admin` → `AdminScreen` (claim approve/reject, user list). `/ledger` → `LedgerScreen`. These are platform-admin tools compiled into the owner binary and gated by `auth.isAdmin`.

## Chat

Owner chat uses legacy `GET /messages/threads` and `GET/POST /messages`. The newer `/chat/groups` API is used by the customer app. Partner plan says chat is not an MVP focus. Leave this path in place.

## Tests

`kocourt_owner/test/router_test.dart` only asserts the router has at least one route. No widget tests for venues, calendar, or bookings.
