# KoCourt Partner — risks and compatibility

**Date:** 31 October 2026

## Customer app compatibility

Both apps share `Booking::isSlotAvailable`, `Booking::create`, pricing calculation, blocks, and `sub_courts`. Any change to those functions changes KoCourt customer checkout.

Safe direction:

- Keep status values `pending`, `confirmed`, `cancelled`.
- Keep `booking_mode` values `exclusive` and `shared`.
- Keep null `sub_court_id` bookings readable.
- Do not add a second availability implementation in Flutter.
- Paid customer creates are rejected on `POST /bookings` when commerce policy says checkout is required (`BookingController::create` returns 409 “Use payment checkout…”). Walk-ins skip that gate. Do not collapse those two paths.

## Data risks

| Risk | Why it matters | What to do before code |
|---|---|---|
| `bookings.user_id` is `NOT NULL` with a foreign key, while walk-ins set `0` | Insert may fail, or a dummy user 0 may exist | Staging query. Do not tighten the FK in the same change that “fixes” guests |
| Direct insert sets `payment_status=paid` | A walk-in looks like collected money | Record method only when a finance phase says how cash is stored |
| Facility delete | Dialog says bookings go away. SQL deletes only `sub_courts`. Bookings can keep a dangling `sub_court_id` | Stop offering delete, or archive, after approval. Do not add `ON DELETE CASCADE` to bookings in passing |
| Court delete | Migration 005 cascades bookings | Prefer deactivate. Do not change delete behavior inside a UI polish task |
| Runtime `ALTER` on request | First request after deploy can change schema | New columns go through a reviewed migration file, not another `try/catch` alter |
| `GET /courts/:id/regulars` returns `u.phone` | Customer phone numbers on a public route | Do not build a directory on this endpoint without an auth check |
| Two notification stores | `/notifications` and `/user-notifications` | Extend one path after confirming which table the owner screen reads |

## Concurrency

`isSlotAvailable` then `INSERT` is two statements with no facility lock. Exclusive courts can double-book. Shared courts can exceed `capacity` for the same reason, and they count rows rather than people.

Payment verification does lock (`SELECT … FOR UPDATE` in `PaymentController`). Booking create does not. Late payment versus an expired hold is not modeled, because there is no hold table. Customer checkout behavior here is **needs verification** against `CommerceCheckout` before anyone describes it as safe.

Recurring create skips conflicting dates and still inserts the rest. The plan’s all-or-nothing rule is not how this endpoint works. Leave it until a booking phase, and do not silently change customer recurring behavior.

## Authorization

- Bookings list uses the token, not the query id. Good.
- Court list uses the query `owner_id`. A caller can ask for another owner’s court list if `Court::read` does not restrict it. Confirm whether that response is the public catalog.
- `GET /bookings/:id` allows court owner and admin, not staff. A manager who can cancel may be forbidden from the detail payload.
- Staff `viewer` is stored and not consistently enforced.
- `GET /bookings` with `court_id` and `date` returns that day’s confirmed bookings, including guest names, without a venue-scope check in the branch that was read.

## Product decisions that block Phase 1

These are not bugs to “fix” by rewriting the shell.

1. **Tabs.** The app ships Venues, Bookings, Earnings, Chat, Profile. The plan specifies Home, Calendar, Facilities, Events, More. Replacing the shell moves every existing path.
2. **Name and color.** The binary is KoCourt Owner with primary `#E23D28`. The plan says KoCourt Partner and `#1A5C35`. The plan also says keep the current design system unless the audit shows a reason to change. This audit does not show a functional reason.
3. **Words.** Code and UI say court and space. The plan says venue and facility. API paths stay `courts` and `sub-courts` either way.
4. **Membership.** `plans` already mean peak-hour access. Package credits are a different feature.

## What not to do in the next slice

- No new tournament tables.
- No status enum migration.
- No production SQL, refund, or payout.
- No second Flutter app and no switch away from Provider and go_router.
- No client-side availability math.
