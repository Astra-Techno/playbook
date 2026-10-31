# Phase 1 task breakdown

**Date:** 31 October 2026  
**Status:** Proposed. Do not start until this audit is approved.  
**Depends on:** Phase 0 (this folder).

Phase 1 in the master plan is the shell: session, venue scope, navigation, loading and error states. Most of that shell already exists. Phase 1 should close the real shell gaps. It should not restyle the app or touch booking writes.

## Already done (no task)

- Login route, session restore, logout via `AuthProvider`.
- Five-tab `IndexedStack` shell.
- Venue list for the token user’s courts, venue create and edit, claim sheet.
- GoRouter guards for login and admin.
- Shared `Api` client and theme.

## Decisions required first

Answer these before any Phase 1 code. Defaults if you want the smallest safe slice:

| Decision | Recommended default |
|---|---|
| Replace bottom tabs with Home / Calendar / Facilities / Events / More? | No. Keep Venues, Bookings, Earnings, Chat, Profile |
| Rename the app to KoCourt Partner and switch primary color to `#1A5C35`? | No. Keep KoCourt Owner and the current theme |
| Add a global selected venue? | Not in Phase 1. Routes already take `courtId` |
| Show staff venues on the Venues tab? | Yes. This is the one shell gap that changes who can operate a venue |

## Tasks (after approval)

### P1-T1 — Staff venues on the Venues tab

**Why:** `GET /court-staff/my-courts` exists. `OwnerDashboardScreen` only calls `GET /courts?owner_id=`, and the server filters by owner. A manager never sees the venue they were invited to.

**Files:** `kocourt_owner/lib/screens/owner/owner_dashboard_screen.dart`. Read `StaffController::myCourts` before coding and match its real JSON keys.

**Done when:** An account that owns venue A and is staff on venue B sees both, with a label that distinguishes owner and staff. Pull-to-refresh reloads both. A failed request shows an error and retry, not an empty list that looks like “no venues”.

**Out of scope:** Editing venue B’s pricing. Staff edit rights stay as they are.

### P1-T2 — Honest empty, error, and loading on the five tabs

**Why:** Several screens use `catch (_) {}` and then render an empty list (`owner_dashboard_screen.dart`, `calendar_screen.dart`, `spaces_screen.dart`).

**Files:** the five tab screens only.

**Done when:** Each tab has a loading state, an error state with retry, and an empty state that is not the same widget as the error state.

**Out of scope:** Calendar timeline, walk-in, payments.

### P1-T3 — Router test for the real shell

**Why:** `test/router_test.dart` only checks that routes are non-empty.

**Done when:** A widget or router test covers logged-out redirect to `/login`, logged-in stay on `/`, and non-admin redirect away from `/admin`.

### Explicitly not in Phase 1

- Fixing `busy_days` vs `days` (calendar correctness, Phase 4 / a dedicated calendar slice).
- Wiring `WalkInSheet` (booking write, after the datetime bug is specified).
- Facility capacity UI (Phase 2).
- Locks, holds, reschedule, tournaments, color rebrand.

## Exit tests for this phase

- Login, logout, and cold start still restore a session.
- Owner still sees owned venues.
- Staff user sees assigned venues and cannot open `/admin`.
- Switching tabs does not crash and does not show another user’s data.
- `flutter analyze` for `kocourt_owner` and the new tests pass.
- No change under `backend/` and no migration file.

## Suggested first prompt after approval

Implement P1-T1 only. Show the files and the `myCourts` response fields before editing. Do not change booking, payment, or schema.
