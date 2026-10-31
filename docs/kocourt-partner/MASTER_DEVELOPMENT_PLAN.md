# KoCourt Partner — Complete Development Plan for Cursor

**Document version:** 1.0  
**Date:** 30 October 2026  
**Product:** KoCourt Partner (Flutter owner/organizer app)  
**Companion product:** KoCourt (customer app)  
**Status:** Implementation blueprint; **not** a claim that existing Flutter code or backend was inspected.  
**Primary instruction:** Audit and extend existing code. Do not rebuild, duplicate, or destructively migrate.

---

## 0. How to use this document in Cursor

1. Place this file at `docs/kocourt-partner/MASTER_DEVELOPMENT_PLAN.md` in the Flutter repository or multi-repository workspace.
2. Open the actual Flutter owner app, relevant backend repository, customer app (if available), and existing SQL schema in Cursor. If repositories are separate, give Cursor access to each or provide documented API contracts.
3. In Cursor Agent, paste the **Master Agent Instruction** in Section 22.
4. Execute **Phase 0: Audit** only. Cursor must produce findings and wait for approval before code changes.
5. Work phase by phase using the exact phase prompts in Section 23. Require a diff summary, test results, and manual QA checklist after every task.
6. Do not run schema changes against production. Generate migrations and a rollback/restore plan, then test on a staging clone.

**Definitions of evidence:**
- **Verified in supplied SQL:** table or column actually exists in the provided database export.
- **Design proposal:** recommended new functionality; must be reconciled with existing code and live schema.
- **To inspect:** Flutter source, backend endpoints, SQL indexes/constraints, operational rules, payments integration, and customer app compatibility are not yet verified.

---

## 1. Product mission and scope

Build a dedicated Flutter application for venue owners, venue staff, and independent tournament organizers to operate sports businesses. The product hierarchy is:

`Owner user → owned/authorized venue(s) [courts] → bookable facility/facilities [sub_courts] → availability calendar → reservations [bookings]`.

**Core goals**
- A single owner can manage multiple venues.
- A venue can contain badminton courts, pickleball courts, turf, swimming pools, gyms, cricket nets, and other facilities.
- Different facilities can use exclusive-slot, shared-capacity, class/session, membership-access, or package-credit booking models.
- Both KoCourt apps must use one authoritative booking/availability/pricing system.
- Online, offline, phone, WhatsApp, walk-in, recurring, and event allocations must not conflict.
- Owners must have reliable business records: revenue, refunds, settlement, staff actions, and occupancy.
- Independent event organizers may manage tournaments without owning a venue, subject to authorization and venue-allocation agreements.

**Out of scope for initial release:** Full league ranking ecosystem, AI features, inventory-heavy retail/POS, elaborate coaching marketplace, complex accounting integrations, and native offline booking commits. These can be staged later.

### 1.1 Product surfaces

| Surface | Audience | Responsibility |
|---|---|---|
| KoCourt customer app | Players | Discover, book, pay, register for events, see own reservations |
| KoCourt Partner Flutter app | Owners/staff/organizers | Operate venues, bookings, facilities, events, staff, finance |
| KoCourt internal admin (existing or future web) | Platform team | Verification, disputes, contracts, commission, sponsorship, moderation |
| Shared backend/API | All | Identity, permissions, scheduling, pricing, payments, events, audit |

Do not create separate databases for customer and partner apps.

---

## 2. Verified database baseline (supplied SQL export)

Source: `dbvklnmy_kocourt.sql` supplied in conversation. It contains **41 CREATE TABLE definitions**. This section records observed columns; it does not prove how backend code currently uses them.

| Table | Relevant verified columns | Implication |
|---|---|---|
| `courts` | `id`, `owner_id`, `name`, `type`, `description`, `location`, `hourly_rate`, `lat`, `lng`, `open_time`, `close_time`, `amenities`, `is_verified`, `claim_status` | Existing venue listing, owner relation, verification and venue-level defaults |
| `sub_courts` | `id`, `court_id`, `name`, `hourly_rate`, `sort_order`, `image_url`, `capacity`, `booking_mode`, `peak_members_override` | Existing child facilities; **capacity and booking mode already exist** |
| `bookings` | `id`, `user_id`, `court_id`, `sub_court_id`, `start_time`, `end_time`, `type`, `total_price`, `status`, `payment_status`, `guest_name`, `guest_phone`, `notes`, `commerce_snapshot`, `payment_id` | Supports facility-level booking and guest details; assess nullable user, status semantics, and concurrency |
| `pricing_rules` | `court_id`, `sub_court_id`, `day_type`, `start_hour`, `end_hour`, `price`, `valid_from`, `valid_to`, `priority` | Venue/facility price rules already supported |
| `blocked_slots` | `court_id`, `sub_court_id`, `start_time`, `end_time`, `reason`, `blocked_by`, `block_kind`, `repeat_annually` | Venue/facility closures already supported |
| `court_staff` | `court_id`, `user_id`, `added_by`, `role` | Staff assignments already venue-scoped; permissions need inspection |
| `payments` | `user_id`, `cf_order_id`, `cf_payment_id`, `amount`, `type`, `status`, `reference_id`, `commerce_snapshot`, `payload` | Payment records exist; inspect Cashfree integration and reconciliation |
| `payouts` | `owner_id`, `amount`, `note`, `recorded_by`, `paid_at` | Basic payout record, not necessarily booking-level settlement ledger |
| `vendor_profiles` | `user_id`, `cf_vendor_id`, `cf_vendor_status`, `commission_pct`, account and tax identifiers | Existing vendor/payout onboarding; sensitive data handling required |
| `plans` | `court_id`, `sub_court_id`, `name`, `duration_days`, `price`, `slot_type` | Existing plan concept; **verify semantics before using for memberships** |
| `user_subscriptions` | `user_id`, `plan_id`, `start_date`, `end_date`, `status`, `court_id`, `slot_type` | Existing subscription concept; confirm entitlement rules |
| `users` | `id`, `name`, `email`, `password`, `phone`, `role`, `auth_token`, `fcm_token` | Existing identity/auth model; security audit needed |
| `booking_players` | `booking_id`, `user_id`, `invited_by` | Multi-player booking associations exist |
| `booking_refunds`, `refund_requests`, `refund_events`, `refund_webhook_events` | Existing refund-related tables | Reuse and inspect full refund lifecycle |
| `user_notifications` | Existing notification table | Extend event types, not parallel notification storage by default |
| `court_photos`, `reviews`, `favorites` | Existing content/feedback tables | Reuse |
| `match_requests`, `match_participants`, `chat_*`, `posts`, `post_*` | Existing social/match functionality | Preserve compatibility; not Partner MVP focus |

**Do not assume:** exact foreign keys, indexes, column enums, uniqueness rules, API responses, payment gateway configuration, or booking model value meanings until verified in source. Existing `sub_courts.booking_mode` values and `bookings.status` values must be documented from schema and code before implementation.

### 2.1 Backward compatibility decisions

1. Keep `courts` as the venue-level table, even though its historical name is “courts.”
2. Keep `sub_courts` as individually configurable facilities.
3. Preserve existing direct-to-`courts` booking flows where `bookings.sub_court_id` is null; treat them as legacy/default facility bookings unless and until safely migrated.
4. Never automatically synthesize sub-courts for all existing venues without migration analysis.
5. Existing `capacity`, `booking_mode`, guest fields, pricing rules, and blocks must be reused before considering new columns.
6. All additive schema changes must include indexes, migration, data backfill where necessary, and rollback/restore guidance.

---

## 3. Core information architecture and navigation

### 3.1 Bottom navigation (5 tabs)

1. **Home:** Dashboard, urgent actions, today's operations, notifications.
2. **Calendar:** Day/week schedule, filters, reservations, add booking, check-in.
3. **Facilities:** Venue selector, venue details, facility list, pricing, schedules, blocks.
4. **Events:** Tournaments, registration lists, check-in, results (progressive release).
5. **More:** Customers, memberships, payments, reports, staff, settings, support.

### 3.2 Global UI rules

- App name: **KoCourt Partner**. Primary green: `#1A5C35`; accessible neutral surfaces; consistent spacing and typography.
- Persistent selected venue across tabs; “All venues” only where aggregation makes sense.
- Clear facility selector and date picker on booking screens.
- Loading, empty, offline, unauthorized, error, retry, and success states for every async screen.
- Avoid client-only authority for permissions, pricing, and availability.
- Mobile-first; tablet calendar may show more facilities side-by-side.
- Preserve existing design system and components unless the audit establishes a compelling reason to change.
- Support accessibility labels, text scaling, safe areas, and keyboard navigation where applicable.
- Display local venue time consistently; store unambiguous timestamps on server.

### 3.3 Complete screen inventory (target)

| ID | Screen | Core actions | Release |
|---|---|---|---|
| A01 | Splash/session restore | Restore session; handle expired token | R1 |
| A02 | Owner login/OTP | Authenticate; handle unverified owner | R1 |
| A03 | Onboarding/profile | Basic owner/business details | R1 |
| A04 | Venue selector | Switch venue; choose all-venue reporting | R1 |
| A05 | Dashboard | Metrics, quick booking, alerts | R1 |
| A06 | Notifications center | Read, navigate, mark seen | R1 |
| V01 | Venue list | View/add/edit owned/assigned venues | R1 |
| V02 | Venue form | Details, map, amenities, hours, policies | R1 |
| V03 | Venue photos | Upload, reorder, delete with permission | R1 |
| F01 | Facility list | Filter/sort/add facility | R1 |
| F02 | Facility form | Sport, name, booking mode, capacity, media | R1 |
| F03 | Facility detail | Status, settings, schedule, bookings | R1 |
| F04 | Facility pricing | Rule CRUD, previews, conflicts | R1 |
| F05 | Hours and closures | Regular hours, exceptions, blocks | R1 |
| B01 | Calendar day | Facility timeline, status colors | R1 |
| B02 | Calendar week | Occupancy, tap slot | R1 |
| B03 | Booking list | Search, filters, pagination | R1 |
| B04 | Booking detail | Timeline, participants, payment, actions | R1 |
| B05 | Create booking wizard | Guest/customer, facility, time, price, confirm | R1 |
| B06 | Reschedule booking | Check alternative slot, reprice, atomic change | R1 |
| B07 | Cancel/refund flow | Policy, reason, approval, refund tracking | R1/R2 |
| B08 | Check-in/no-show | Verify arrival, mark usage | R1 |
| P01 | Payment list | Collections and statuses | R2 |
| P02 | Payment detail | Reconcile, receipt, refund state | R2 |
| P03 | Earnings/settlements | Gross, fees, net, payout history | R2 |
| T01 | Event list | Draft, published, past | R2 |
| T02 | Event wizard | Create event, categories, rules, publish | R2 |
| T03 | Event detail | Overview, registrations, operations | R2 |
| T04 | Registration list | Search, approve, waitlist, export | R2 |
| T05 | Participant detail | Entry, team, payment, check-in | R2 |
| T06 | Event court allocation | Reserve venue resources safely | R2 |
| T07 | Draws/matches/scores | Brackets, results | R3 |
| M01 | Membership plans | Configure entitlement and prices | R3 |
| M02 | Membership holders | Activate, renew, suspend, usage | R3 |
| C01 | Customer directory | Search guest/registered customers | R2 |
| C02 | Customer detail | Authorized booking history, notes | R2 |
| S01 | Staff list/invites | Assign staff to venue | R3 |
| S02 | Staff permissions | Role-based actions, revoke access | R3 |
| R01 | Reports | Revenue, occupancy, conversion | R3 |
| R02 | Exports | CSV/PDF if supported; authorization | R3 |
| X01 | Settings | Venue policies, business profile, security | R1/R3 |
| X02 | Help/support | Ticket/dispute escalation | R3 |
| X03 | Maintenance | Blocks, affected bookings, resolution | R1 |
| X04 | Optional services | Coaching/equipment add-ons | R4 |

**Release definitions:** R1 = venue operations MVP; R2 = events/finance; R3 = growth/advanced ops; R4 = optional expansion.

---

## 4. Functional specifications and acceptance criteria

### 4.1 Authentication and owner onboarding

**Inputs:** Existing login/OTP mechanism, user identity, owner/vendor profile. **Audit first:** determine whether user role and venue ownership are sufficient or whether claim approval is required.

**Flow:** Launch → restore token → fetch current identity and accessible venues → select venue → dashboard. If no venue, offer create/claim venue where permitted. For unverified venues, show a clear pending status and restrict publication/payout actions according to platform policy.

**Rules:**
- Secure token storage; revoke on logout; no passwords or tokens in logs.
- Backend authorization for each endpoint; reject stale/revoked access.
- Venue selector includes owned venues and authorized staff venues only.
- Claim/verification state from `courts.claim_status` / `is_verified` is authoritative.
- Sensitive bank/tax data in `vendor_profiles` must not be exposed in generic profile responses.

**Done when:** login/restore/logout and permission denial are tested; venue switching refreshes all scoped data; unauthorized venue ID returns 403/404 as appropriate.

### 4.2 Venue management (`courts`)

**Fields:** Name, type/venue category, description, address/location, coordinates, contacts, opening hours, amenities, photos, policy text, visibility and verification state. Map new fields only after schema audit.

**Actions:** list, create, edit, submit claim/verification, upload photos, preview customer listing, request publication. Use optimistic updates only for safe non-financial fields.

**Rules:** owner cannot self-verify; venue deletion should generally be archive/deactivate and must check bookings; never orphan facilities or bookings.

**Done when:** changes appear in customer listing according to publication rules; validation covers required name/location; media errors are recoverable.

### 4.3 Facility management (`sub_courts`)

**Fields:** Parent venue, facility name, sport, description, photo, sort order, base rate, capacity, booking mode, operational status, duration limits and availability overrides (only add missing fields after audit).

**Booking models:**
- `exclusive_slot`: one capacity unit per interval; cannot overlap another confirmed booking/active hold/block.
- `shared_capacity`: concurrent reservations allowed while total committed quantity ≤ capacity.
- `session_class`: fixed instructor-led session with capacity; needs explicit session records.
- `membership_access`: access entitlement, optionally with capacity/time reservation.
- `package_credit`: booking requires available credits; credits redeemed atomically.

**Important:** These are **proposed semantic names**. Do not overwrite existing `booking_mode` values; inspect and map them first.

**Done when:** owner can create/edit facilities, set mode and capacity, and see each facility independently in the calendar and customer app.

### 4.4 Operating hours, pricing, and closures

**Pricing precedence proposal:** explicit event/package agreement > authorized booking override > applicable facility pricing rule by priority/specificity > facility base rate > venue base rate. Exact existing precedence must be discovered and preserved unless intentionally changed.

**Inputs:** date, local time, duration, venue/facility, quantity, user entitlement, applicable rules, promotion, tax/fees.

**Outputs:** authoritative quote with breakdown, currency, effective expiry, and pricing version/snapshot.

**Rules:** overlapping pricing rules require deterministic resolution; reject ambiguous configurations or surface preview. Holiday exceptions and overnight hours need explicit support. Facility block should not automatically erase existing reservations.

**Done when:** calendar and customer app show identical availability/price for same inputs; historical booking prices remain immutable.

### 4.5 Booking calendar

**Day view:** vertical time axis, facility columns, colored bookings/blocks, time-now indicator, tap-to-create, drag/resize only if safe and explicitly confirmed. **Week view:** facility/date occupancy. **Month view:** summary, not detailed time slots.

**Filters:** venue, facility, sport, booking status, source, payment state. **Refresh:** on foreground, mutation, and push-triggered invalidation; polling or websocket only if needed.

**Done when:** bookings and blocks are accurately shown; venue switching cannot display stale data from another venue; daylight/timezone edge cases tested.

### 4.6 Booking lifecycle

**Proposed booking statuses:** draft/held, pending, confirmed, checked_in, completed, cancelled, no_show, expired. **Do not alter existing status values until audited.** Track payment status independently.

**Creation flow:** choose venue/facility → select interval/quantity → check capacity → select registered customer or guest → server quote → optional owner-approved price adjustment → choose payment method → server-side reservation transaction → confirmation/hold → receipt/notification.

**Sources:** customer online, walk-in, phone, WhatsApp, owner manual, admin, membership, tournament allocation. Use a source field only if needed and missing.

**Guest:** existing `guest_name` and `guest_phone` should be reused; verify `user_id` nullability and business logic before enabling unauthenticated guest records.

**Check-in:** verified owner/staff can check in; prevent duplicate check-in; no-show can be marked after policy-defined grace period. Check-out/completion may be automatic after end time, but preserve attendance distinctions.

**Reschedule:** reserve new capacity atomically before releasing old capacity; calculate price difference; avoid releasing old slot if replacement/payment fails. Keep audit history.

**Cancellation:** evaluate cancellation policy, record reason/actor, release capacity, trigger eligible refund separately; avoid immediate irreversible refund assumptions.

**Done when:** online and manual bookings never double-book; retries are idempotent; changes reflect in both apps.

### 4.7 Availability and concurrency — critical implementation

**Canonical resource occupancy:** The system must compute committed capacity from all booking sources, active holds, maintenance blocks, and event allocations. Prefer a unified reservation ledger only if current data/queries cannot reliably enforce this; do not create a redundant ledger without migration and reconciliation design.

**Interval overlap rule:** `[existing_start < requested_end] AND [existing_end > requested_start]` for half-open intervals. Confirm identical timezone interpretation.

**Exclusive:** available if no conflicting committed reservation or block. **Shared:** available if sum of overlapping reserved quantities + requested quantity ≤ capacity. For variable-length overlaps, calculate at each boundary or use discrete capacity units.

**Transaction requirements:**
- Lock the canonical facility or an appropriate scheduling row/key before capacity check and insert.
- Use a single DB transaction for availability check + reservation commit.
- Apply unique/idempotency keys for client retries.
- Holds have server-enforced expiry; late payment success is reconciled, never used to silently overbook.
- Booking updates/cancellations and tournament allocations use the same lock order to avoid deadlocks.
- Add indexes for venue/facility/start/end/status and hold expiry after inspecting existing indexes.

**Concurrency tests:** 50+ parallel requests for a single exclusive slot must produce exactly one success; shared capacity must never exceed limit; expired hold races must not produce duplicate confirmations.

### 4.8 Payments, refunds, payouts

**Existing integration hints:** `payments.cf_order_id`, `cf_payment_id`, and `vendor_profiles.cf_vendor_id` suggest Cashfree; verify actual provider configuration and integration before changing it.

**Payment types:** online, cash, external UPI, pay-at-venue, split/partial payment if approved. Store recorded method and collection source, not only a generic “paid” flag.

**Accounting separation:** booking gross, discounts, taxes, collected amount, refunds, payment fees, KoCourt commission, settlement amount, payout status. A booking is not a payout. Reconcile every amount to payment events.

**Rules:** verify webhook signatures; idempotent webhook processing; never trust client payment success callback; refund authorization and refund provider result are separate; mask bank account details; audit manual payment adjustments.

**Done when:** finance report matches reconciled payment ledger and refunds; duplicate webhooks do not duplicate collections or payouts.

### 4.9 Tournaments and independent organizers

**Organizer model:** An organization may own zero or many venues; an organizer may use a venue with permission without owning it. Prefer a scoped organizer capability, not `courts.owner_id` spoofing.

**Event wizard:** details → sport/type → venue/location → categories → entry rules/fees → dates/capacity → court allocations → preview → publish.

**Category fields:** singles/doubles/team, gender/age/skill eligibility where applicable, entry fee, max teams/players, registration deadline, approval requirement, waitlist policy.

**Registration:** individual/pair/team; captain/partner linking; payment; approval; confirmed/waitlisted/cancelled/refunded; duplicate registration prevention. Never expose participants' private information to unrelated organizers.

**Court allocations:** reserve physical facilities through shared occupancy engine; no independent tournament calendar that can double-book.

**Operations:** QR or code check-in, attendance, CSV export, organizer announcements. Later: brackets, draws, match scoring, results, rankings.

**Sponsorship:** optional internal-admin-managed agreement and attribution fields; owners can view approved sponsorship assets, not unilaterally approve platform sponsorship.

**Done when:** an organizer can publish an event and accept registrations without owning a venue; paid registration and event capacity are safe under concurrency.

### 4.10 Memberships, packages, coaching, and services

**Inspect first:** `plans` and `user_subscriptions` may already be membership-related; verify business rules before extending.

**Plans:** duration, eligible facilities, time windows, max uses per day/week, advance-booking limit, blackout periods, renewal, freeze, refund policy.

**Usage ledger:** record each entitlement credit/debit and booking linkage; prevent double redemption; restore credit only according to cancellation policy.

**Classes:** schedule, instructor, capacity, enrollment, attendance. **Equipment:** optional rental/add-on with quantity, deposit, and return status; do not include in MVP unless demand warrants.

**Done when:** membership does not bypass capacity checks and expired/frozen plans cannot redeem.

### 4.11 Customers, staff, reports, notifications

**Customers:** venue-scoped customer list; guest identity matching should avoid automatically merging users on phone alone; access only to data relevant to venue operations.

**Staff roles:** owner, manager, receptionist, coach, organizer. Implement action-level permissions and venue scope on backend; frontend only reflects granted capabilities.

**Reports:** revenue (gross vs collected vs net), occupancy = booked usable time / available usable time, cancellations, repeat customers, event registrations, event-to-booking conversion, facility utilization. Define exact filters and refund handling.

**Notifications:** durable event-driven in-app/push; deduplicate by event key; customer and owner notification templates; avoid sending sensitive data in push payloads.

**Done when:** manager cannot access another venue by changing an ID; report values reconcile with source records; notification retries do not spam.

---

## 5. Data model and migrations — proposal, not executable SQL

**Rule:** Cursor must produce a schema comparison before creating any new table. Existing columns in Section 2 must not be duplicated.

### 5.1 Likely additions (subject to audit)

| Proposed table / change | Why | Priority | Notes |
|---|---|---|---|
| `booking_holds` or existing hold enhancement | Expiring payment reservations | P0 | Reuse existing hold semantics if present in backend |
| `booking_audit_events` | Immutable actor/time/changes | P0 | Do not duplicate existing audit system if reusable |
| `resource_reservations` (conditional) | Unified occupancy for events, bookings, blocks | P0 conditional | Add only after proving existing tables insufficient |
| `facility_schedules` / `schedule_exceptions` (conditional) | Facility-specific hours | P1 | Check current schedule code first |
| `booking_payment_allocations` (conditional) | Partial payments and reconciliation | P1 | Link existing payments/bookings |
| `settlement_items` (conditional) | Booking-level payout allocation | P1 | Keep existing `payouts` |
| `event_organizers` / organizer role model | Independent organizers | P1 | Reuse existing user/organization model if present |
| `events` | Tournament/event record | P1 | New dedicated event domain |
| `event_categories` | Entry classes | P1 | Fee/capacity/rules |
| `event_registrations` | Entries | P1 | Payment/approval states |
| `event_teams`, `event_team_members` | Doubles/team rosters | P1 | Support individual registration too |
| `event_resource_allocations` | Court scheduling | P1 | Must share occupancy enforcement |
| `event_checkins` | Attendance | P1 | QR/code with expiry/replay protection |
| `event_matches`, `event_results` | Draws/scores | P2 | Later release |
| `membership_usage_events` (conditional) | Credit/entitlement ledger | P2 | Check current subscription implementation |
| `staff_permissions` (conditional) | Fine-grained access | P2 | May be role-permission mapping instead |
| `notification_outbox` (conditional) | Durable delivery/retries | P1 | Reuse existing queue/outbox infrastructure |

### 5.2 Migration requirements

Each migration proposal must include: current schema excerpt; reason; DDL; index/foreign-key plan; data backfill; impact on existing API and customer app; deploy order; verification queries; rollback strategy; expected locking/downtime. Prefer expand → deploy compatible code → backfill → switch reads/writes → contract only in a separately approved future release.

Never modify production data or run destructive SQL autonomously.

---

## 6. API design and contracts

Use existing API naming, auth, response envelopes, and versioning conventions discovered during audit. Below are **target conceptual endpoints**, not proof they exist.

### 6.1 Owner API inventory

```text
GET    /api/v1/partner/me
GET    /api/v1/partner/venues
POST   /api/v1/partner/venues
GET    /api/v1/partner/venues/{venueId}
PATCH  /api/v1/partner/venues/{venueId}
GET    /api/v1/partner/venues/{venueId}/facilities
POST   /api/v1/partner/venues/{venueId}/facilities
PATCH  /api/v1/partner/facilities/{facilityId}
GET    /api/v1/partner/facilities/{facilityId}/pricing
PUT    /api/v1/partner/facilities/{facilityId}/pricing-rules/{ruleId}
GET    /api/v1/partner/availability?venue_id=&facility_id=&date=
POST   /api/v1/partner/quotes
GET    /api/v1/partner/bookings
POST   /api/v1/partner/bookings
GET    /api/v1/partner/bookings/{bookingId}
POST   /api/v1/partner/bookings/{bookingId}/reschedule
POST   /api/v1/partner/bookings/{bookingId}/cancel
POST   /api/v1/partner/bookings/{bookingId}/check-in
POST   /api/v1/partner/blocks
DELETE /api/v1/partner/blocks/{blockId}
GET    /api/v1/partner/dashboard?venue_id=&date=
GET    /api/v1/partner/payments
GET    /api/v1/partner/settlements
GET    /api/v1/partner/events
POST   /api/v1/partner/events
PATCH  /api/v1/partner/events/{eventId}
POST   /api/v1/partner/events/{eventId}/publish
GET    /api/v1/partner/events/{eventId}/registrations
POST   /api/v1/partner/events/{eventId}/registrations/{id}/check-in
GET    /api/v1/partner/customers
GET    /api/v1/partner/staff
POST   /api/v1/partner/staff/invitations
GET    /api/v1/partner/reports
GET    /api/v1/partner/notifications
```

**Important:** Cursor should reuse existing endpoints and add a partner namespace only when needed; do not duplicate business logic into a new service layer.

### 6.2 Request/response requirements

- JSON and existing backend conventions; strict validation.
- Authorization from token/session and venue scope, not client-supplied owner ID.
- Server-generated IDs, timestamps, totals, and payment status.
- Pagination for list endpoints; filtering/sorting with allowlisted fields.
- Stable error codes: `UNAUTHORIZED`, `FORBIDDEN`, `VALIDATION_ERROR`, `VENUE_NOT_FOUND`, `CAPACITY_CONFLICT`, `HOLD_EXPIRED`, `PRICE_CHANGED`, `PAYMENT_PENDING`, `INVALID_TRANSITION`, `RATE_LIMITED`.
- Return a conflict response with current availability/quote where safe.
- `Idempotency-Key` for booking creation, refunds, payment initiation, and event registration.
- Server-side state transition validation and audit event.

### 6.3 Example: create manual booking (illustrative contract)

```json
{
  "venue_id": 12,
  "facility_id": 41,
  "start_at": "2026-11-01T18:00:00+05:30",
  "end_at": "2026-11-01T19:00:00+05:30",
  "quantity": 1,
  "source": "walk_in",
  "guest": {"name": "Guest Player", "phone": "<optional phone>"},
  "payment_method": "pay_at_venue",
  "quote_id": "server-issued-quote-id"
}
```

Response should include booking ID, state, venue/facility, committed interval, final price snapshot, payment state, and server timestamps. If current schema cannot support a field, adapt contract after audit; do not invent silent mappings.

---

## 7. Flutter implementation architecture

**First inspect the existing project.** Do not impose Riverpod, Bloc, GetX, GoRouter, Dio, Retrofit, or a new directory layout if equivalent frameworks are already in use.

### 7.1 Target logical layers

```text
Presentation (screens, widgets, navigation, view models/state)
        ↓
Application (use cases, validation, orchestration)
        ↓
Domain (entities, value objects, status transitions)
        ↓
Data (repositories, API clients, DTOs, local cache)
        ↓
Shared backend (authoritative scheduling, pricing, payments)
```

### 7.2 Feature boundaries

```text
features/
  auth/
  dashboard/
  venues/
  facilities/
  calendar/
  bookings/
  pricing/
  events/
  payments/
  memberships/
  customers/
  staff/
  reports/
  notifications/
  settings/
shared/
  api/
  auth/
  routing/
  theme/
  widgets/
  errors/
  telemetry/
```

This is a conceptual feature map, **not** an instruction to move working files. Prefer incremental feature folders and adapters.

### 7.3 Engineering standards

- Strongly typed DTOs; no `dynamic` mapping scattered across widgets.
- Repository interfaces for network operations; easy to mock in tests.
- Centralized API errors and unauthorized-session handling.
- Cancel/ignore stale requests when selected venue changes.
- Persist only safe UI state; do not cache financial/booking authority for offline writes.
- Keep secrets out of source and logs; environment-specific configuration.
- Reusable forms, date/time picker, money formatting, status chips, empty/error states.
- Widget tests for core screens; integration tests for critical workflows.
- Add analytics/crash reporting only after checking existing integrations and privacy policy.

---

## 8. Role and authorization matrix

| Capability | Owner | Venue manager | Receptionist | Coach | Independent organizer |
|---|---|---|---|---|---|
| View assigned venue | Yes | Yes | Yes | Assigned | Venue by agreement |
| Edit venue details | Yes | Allowed by policy | No | No | No |
| Manage facilities/pricing | Yes | Allowed by policy | No | No | No |
| Create walk-in bookings | Yes | Yes | Yes | Optional | No |
| Cancel bookings | Yes | Allowed by policy | Limited | No | Event-only |
| Record collections | Yes | Allowed | Allowed | No | Event-only |
| View payout/bank data | Yes | Restricted | No | No | Own event finances only |
| Create/publish tournaments | Yes | Allowed | No | Optional | Yes |
| Check in participants | Yes | Yes | Yes | Optional | Own events |
| Invite staff | Yes | Limited | No | No | Event volunteers only |
| View all-venue reports | Yes | Assigned only | No | No | Own events only |

Backend must enforce each capability. Roles are defaults; actual permissions must be granular and scoped.

---

## 9. Nonfunctional requirements

- **Reliability:** booking and payment mutations are idempotent; audit trail and reconciliation jobs.
- **Security:** OWASP mobile/API fundamentals, rate limits, parameter validation, least privilege, secret rotation, secure storage, protected vendor data.
- **Performance targets (initial):** dashboard first usable data under 3s on a reasonable mobile network; calendar initial visible week under 3s for a normal-sized venue; refine after profiling.
- **Scalability:** pagination, server-side aggregation, indexes, avoid N+1 queries, cache nonauthoritative lookups.
- **Observability:** correlation IDs, structured error logs, metrics for payment failures, booking conflicts, notification failures, webhook latency.
- **Accessibility:** scalable text, sufficient contrast, readable touch targets, screen-reader labels.
- **Localization:** Indian currency and local date formats initially; timezone-aware design for expansion.
- **Privacy:** collect only necessary customer data; venue-scoped access; documented retention and consent.
- **Release safety:** feature flags for new booking modes; staged rollout; migration and rollback drills.

---

## 10. Detailed implementation roadmap and dependencies

### Phase 0 — Audit and gap analysis (NO CODE CHANGES)

**Tasks**
1. Inventory Flutter project structure, dependencies, app IDs, build flavors, routing, state management, existing screens, reusable widgets.
2. Inventory backend repositories, auth flow, endpoints, services, background jobs, payment/webhook handlers.
3. Inspect live-compatible schema and migrations; compare with supplied SQL export; document all enums, constraints, indexes.
4. Trace customer app booking and payment flows end-to-end.
5. Classify each target feature as complete/partial/missing/needs verification.
6. Identify missing repo access or external service credentials without requesting secrets in chat.
7. Build dependency graph and prioritized implementation backlog.

**Deliverables**
- `docs/kocourt-partner/audit/architecture.md`
- `docs/kocourt-partner/audit/screen-inventory.md`
- `docs/kocourt-partner/audit/api-inventory.md`
- `docs/kocourt-partner/audit/database-inventory.md`
- `docs/kocourt-partner/audit/feature-gap-matrix.md`
- `docs/kocourt-partner/audit/risks-and-compatibility.md`
- `docs/kocourt-partner/audit/phase-1-task-breakdown.md`

**Exit gate:** Owner reviews audit; no implementation until approval.

### Phase 1 — Foundation and venue navigation

**Dependencies:** Phase 0 accepted.

**Tasks:** session restore, auth guard, role/venue scope, venue switcher, app shell/bottom tabs, consistent theme, error/loading states, owner onboarding/claim flow if missing, shared API repositories. Reuse existing code.

**Exit tests:** login/logout, venue switching, expired token, owner vs staff access, no cross-venue data leakage, Android/iOS build.

### Phase 2 — Venue and facility CRUD

**Tasks:** venue list/detail/edit, photos, facilities list/detail/form, sport/type mapping, capacity and booking-mode mapping, verification/publication states, archive safety. Add only missing schema fields.

**Exit tests:** owner adds a venue and two facilities; updates are visible in customer app where published; staff cannot edit unauthorized venue; existing legacy court listing works.

### Phase 3 — Scheduling, pricing, and closures

**Tasks:** existing pricing-rule inspection; rate editor and preview; operating hours and facility overrides; block/unblock UI; schedule exceptions; canonical availability service and tests. Protect historical pricing snapshots.

**Exit tests:** peak/weekend pricing resolves deterministically; full-venue block covers all facilities; sub-court block affects only its facility; customer app matches partner availability.

### Phase 4 — Booking calendar and manual operations

**Tasks:** day/week/month calendar, booking list/detail, manual booking wizard, guest booking, check-in/no-show, cancel/reschedule, server concurrency protection, payment holds, audit history, notification triggers.

**Exit tests:** walk-in booking instantly removes slot from customer app; concurrent booking tests pass; cancellation and reschedule never create capacity errors; no duplicate booking from retry.

### Phase 5 — Dashboard, collections, refunds, and settlements

**Tasks:** daily KPIs, booking/occupancy summary, collections UI, pay-at-venue records, refunds, payout view, financial reconciliation and export. Inspect Cashfree vendor integration.

**Exit tests:** all totals reconcile with test payments and refunds; payouts not confused with booking gross; staff financial visibility restricted; webhook replay safe.

### Phase 6 — Tournaments MVP

**Tasks:** organizer authorization, event/category wizard, individual/doubles/team registrations, capacity/waitlist, payment status, event court allocation, publishing, participant list, check-in, notifications, CSV export, sponsorship attribution (if configured).

**Exit tests:** organizer without venue ownership can manage an authorized event; tournament reservation blocks conflicting public bookings; registration concurrency respects category capacity; payment and approval state consistent.

### Phase 7 — Memberships, customers, staff, analytics

**Tasks:** existing plan semantics audit, plan management, entitlement/usage ledger, member bookings, customer directory, staff invitations and permissions, occupancy/revenue reports, cancellation and conversion metrics.

**Exit tests:** credits never double-redeemed; memberships obey capacity; cross-venue permissions tested; reports reconcile to source transactions.

### Phase 8 — Advanced operations and polish

**Tasks:** tournament draws/matches/results, coaching sessions, optional rentals, improved alerts, localization, accessibility, performance profiling, release polish.

**Exit tests:** advanced modules have own test coverage and can be feature-flagged without disrupting booking core.

### Phase 9 — Full release hardening

**Tasks:** production-like staging, migration rehearsal, security review, load/concurrency tests, backup/restore drill, regression across both apps, app-store assets, privacy/terms, crash monitoring, support runbook.

**Exit tests:** all release checklist items in Section 18 signed off.

---

## 11. Prioritized backlog (implementation-ready epics)

| Epic | Priority | Depends on | Deliverable |
|---|---|---|---|
| E00 Audit current repos/schema | P0 | None | Evidence-based gap report |
| E01 Auth and venue scoping | P0 | E00 | Secure owner/staff access |
| E02 Navigation and shared UI | P0 | E00 | Working app shell |
| E03 Venue/facility management | P0 | E01 | Venue → facilities flow |
| E04 Pricing and schedule | P0 | E03 | Owner controls availability |
| E05 Concurrency-safe booking engine | P0 | E03/E04 | Reliable reservations |
| E06 Calendar and manual booking | P0 | E05 | Daily venue operations |
| E07 Dashboard and alerts | P1 | E05 | Operational overview |
| E08 Payments and refunds | P1 | E05 | Accurate collections |
| E09 Organizer/event model | P1 | E01 | Independent organizer support |
| E10 Tournament registration | P1 | E09/E08 | Paid/free registrations |
| E11 Event court allocation | P1 | E05/E09 | No calendar conflicts |
| E12 Customer directory | P2 | E06 | Customer management |
| E13 Membership entitlements | P2 | E05/E08 | Passes/subscriptions |
| E14 Staff permissions | P2 | E01 | Delegated operations |
| E15 Reports and settlements | P2 | E08 | Financial/operational insights |
| E16 Draws, scoring, coaching | P3 | E10 | Advanced ecosystem |
| E17 Security/load/release | P0 continuous | All | Safe production release |

Every epic must be decomposed into PR-sized tasks, with acceptance criteria, impacted files, migrations, and tests.

---

## 12. Detailed acceptance scenarios (Given / When / Then)

**AC01: Venue hierarchy**  
Given an owner has a venue with two badminton courts and one pool, when they open Facilities, then all three are shown under the same venue and each can be configured independently.

**AC02: Venue switch**  
Given an owner manages venues A and B, when they select B, then all calendar, dashboard, and facility data is scoped to B and cached A data is not displayed as B.

**AC03: Exclusive slot concurrency**  
Given one available badminton slot, when two users attempt to confirm concurrently, then at most one reservation succeeds and the other receives a capacity conflict.

**AC04: Shared pool capacity**  
Given a pool session capacity of 20 and 19 places reserved, when a request for two places arrives, then the request is rejected or adjusted only through an explicit user action.

**AC05: Manual booking**  
Given an open 6–7 PM slot, when reception confirms a walk-in booking, then the customer app no longer offers that slot and the booking appears in Partner calendar.

**AC06: Payment webhook replay**  
Given a payment success webhook was processed, when the same event arrives again, then no duplicate payment, booking, notification, or settlement is created.

**AC07: Reschedule safety**  
Given a confirmed booking, when a requested new slot is occupied, then the original booking remains confirmed and unchanged.

**AC08: Facility closure**  
Given a facility has future bookings, when the owner schedules maintenance, then the app shows conflicts and requires explicit resolution before committing a conflicting block.

**AC09: Organizer independence**  
Given a tournament organizer owns no venue, when they have permission to use a venue for an event, then they can create/register participants for that event without gaining venue-owner permissions.

**AC10: Tournament capacity**  
Given one event category spot remains, when two registrations complete concurrently, then no more than one confirmed entry occupies the final spot.

**AC11: Membership entitlement**  
Given a member has one hour credit remaining, when two redemption requests arrive concurrently, then no more than one hour can be consumed.

**AC12: Staff access**  
Given a receptionist is assigned only to venue A, when they request venue B's financial report by editing the URL/ID, then the backend denies access.

**AC13: Legacy compatibility**  
Given a legacy booking with null `sub_court_id`, when the new app/calendar is deployed, then the booking remains visible and cannot be silently invalidated.

**AC14: Price snapshot**  
Given a confirmed booking priced at ₹500, when the owner changes future rate to ₹600, then the confirmed booking remains ₹500 unless an authorized adjustment is recorded.

**AC15: Offline safety**  
Given the owner device loses connectivity, when they attempt to confirm a booking, then the app does not claim confirmed capacity without server acknowledgment.

---

## 13. Testing strategy

### 13.1 Flutter
- Unit: formatters, validation, state transitions, venue selection, calendar layout calculations.
- Widget: login, facility form, calendar, booking wizard, event wizard, empty/error states.
- Integration: owner login → venue → facility → manual booking → cancel; tournament publish → registration → check-in.
- Golden screenshots only if current project already uses a stable golden test setup; avoid brittle mass snapshot generation.

### 13.2 Backend
- Unit: pricing precedence, eligibility, booking transitions, cancellation rules, permissions.
- Integration: DB transactions, capacity locks, payment webhooks, refunds, payouts, event allocations.
- Concurrency: exclusive and shared capacity under parallel load; booking + maintenance races; event registrations.
- Security: IDOR/cross-venue access, token expiry, role escalation, request tampering, webhook signature validation.
- Regression: all existing customer booking, refund, subscription, chat, and social flows touched by shared APIs.

### 13.3 Database
- Migration up on staging copy; verify row counts and foreign keys; rollback rehearsal where possible.
- Query plan review for calendar and dashboard endpoints.
- Data reconciliation for booking state, payment state, event capacity, and legacy records.

---

## 14. Operational rules and edge cases

1. Overnight venue operating hours crossing midnight.
2. Facility-specific closure inside venue operating hours.
3. Whole-venue closure with multiple affected facilities.
4. Payment success after hold expiry; reconcile/refund rather than overbook.
5. Duplicate owner button taps and network retries.
6. Legacy booking with `sub_court_id = NULL`.
7. Customer changes time zone; venue schedule remains in venue local time.
8. Staff loses access while editing a booking.
9. Owner attempts to delete a facility with future reservations.
10. Two pricing rules overlap at same priority.
11. Shared-capacity quantity change after booking.
12. Multiple facilities allocated to one tournament.
13. Tournament cancellation with paid registrations.
14. Partial refund after partial attendance or add-on purchase.
15. Guest phone duplicates an existing account; do not silently merge.
16. Owner records cash payment then customer pays online; reconcile double collection.
17. Multi-slot booking partially fails; all-or-nothing capacity commit unless explicitly supported.
18. Membership booking at expiry boundary.
19. Venue claimed by another user; dispute and verification process.
20. Slow/unavailable notification provider must not roll back successful booking.

---

## 15. Security and privacy checklist

- Backend validates role + venue scope + action for every endpoint.
- Sensitive bank, PAN, and account identifiers masked and restricted.
- No hardcoded API secrets, webhook secrets, or access tokens in Flutter.
- HTTPS, secure token storage, expiration/revocation.
- File upload size/type validation and safe storage.
- Parameterized SQL, no raw interpolated filters.
- Audit sensitive mutations with actor and reason.
- Rate-limit OTP, login, booking attempts, and payment actions.
- No sensitive customer details in push notifications or verbose logs.
- Refund and payout operations require privileged authorization.
- Organizer can see only their event's participant data.

---

## 16. Performance and observability

- Paginate bookings, customers, registrations, payments.
- Calendar query uses bounded date window and facility filters.
- Dashboard aggregations are server-side and cacheable for a short interval where safe.
- Use consistent request/correlation IDs across app/API/jobs.
- Monitor booking conflict rate, failed holds, late payments, webhook failures, refund latency, push failures, slow queries, crash-free sessions.
- Instrument venue-switch bugs and stale state separately.

---

## 17. Definition of Done for every Cursor task

A task is **not complete** merely because a screen renders.

1. Existing implementation was inspected and reused where appropriate.
2. Acceptance criteria are documented and met.
3. Backend validation and authorization are enforced.
4. Database changes are additive, reviewed, and migration-tested.
5. Loading, empty, error, retry, offline states implemented.
6. Unit/widget/integration tests added or updated.
7. `flutter analyze` and relevant tests pass; backend tests pass.
8. No regressions in existing KoCourt customer app flows.
9. API documentation and feature status matrix updated.
10. Cursor provides changed files, rationale, commands run, test output, risks, and next task.

If a test cannot run because of missing dependencies or credentials, report it as **not verified**, never as passed.

---

## 18. Release checklist

- [ ] Phase 0 audit approved
- [ ] Auth/permissions verified for owner and staff
- [ ] Venue → facility navigation complete
- [ ] Existing customer bookings still work
- [ ] Facility capacity and booking mode tested
- [ ] Pricing and availability consistent across apps
- [ ] Manual bookings, cancellations, reschedules tested
- [ ] Payment webhooks idempotent and reconciled
- [ ] Refund/payout records verified
- [ ] Tournament registration and allocation tested
- [ ] Legacy bookings handled safely
- [ ] Migration rehearsal and backup/restore verified
- [ ] Concurrency tests pass
- [ ] Security/IDOR tests pass
- [ ] Crash/error monitoring configured
- [ ] Android release build tested
- [ ] iOS release build tested if part of launch
- [ ] Owner onboarding and support process ready
- [ ] Pilot venue feedback reviewed
- [ ] Rollback/incident runbook documented

---

## 19. Recommended MVP pilot in Sivakasi

Pilot with 1–3 venues of different configurations: a single-court venue, a multi-badminton venue, and a multi-sport complex if available. Validate owner setup, walk-in booking speed, calendar accuracy, peak pricing, payment reconciliation, and real customer booking synchronization. Do not roll out advanced tournament scoring or package entitlements before the core availability engine is stable.

**Success signals (targets to agree, not measured facts):** no confirmed double bookings; owner can create a walk-in booking in under 30 seconds after familiarization; daily revenue report reconciles to collections; customer app availability matches owner calendar; pilot owners can complete common tasks without developer intervention.

---

## 20. Recommended repository documentation layout

```text
docs/kocourt-partner/
  MASTER_DEVELOPMENT_PLAN.md
  audit/
    architecture.md
    screen-inventory.md
    api-inventory.md
    database-inventory.md
    feature-gap-matrix.md
    risks-and-compatibility.md
    phase-1-task-breakdown.md
  specifications/
    booking-state-machine.md
    booking-availability.md
    pricing-rules.md
    permissions.md
    payment-reconciliation.md
    tournament-registration.md
  api/
    partner-openapi.yaml
  migrations/
    migration-proposals.md
  qa/
    acceptance-tests.md
    regression-matrix.md
    release-checklist.md
  progress/
    STATUS.md
    DECISIONS.md
```

Cursor should create these incrementally; do not generate fictional API docs from assumptions.

---

## 21. Cursor operating protocol

For every development session:

1. Read this master plan, latest `audit/` findings, `progress/STATUS.md`, and `progress/DECISIONS.md`.
2. Identify exactly one approved epic and a small implementation slice.
3. Inspect the relevant existing code and schema.
4. State planned files, API changes, migrations, test coverage, and compatibility risks.
5. Implement only the approved slice.
6. Run formatting, static analysis, tests, and build checks that are available.
7. Summarize diff and test evidence.
8. Update `STATUS.md` with complete/partial/blocked and exact next task.
9. Stop at any irreversible database/payment/production action and ask for approval.

Do not replace existing architecture because a different package is fashionable. Do not mark incomplete work as complete. Do not silently change customer API semantics.

---

## 22. MASTER AGENT INSTRUCTION — paste into Cursor Agent

```text
You are the lead Flutter and backend architect for KoCourt Partner.

Read docs/kocourt-partner/MASTER_DEVELOPMENT_PLAN.md fully.

The existing KoCourt customer app and Partner owner app share a backend/database. The supplied SQL schema uses `courts` for venue listings and `sub_courts` for individual facilities. `sub_courts` already has `capacity` and `booking_mode`. `bookings` already has `sub_court_id`, guest fields, payment status, and commerce snapshot. Pricing and blocked slots can target sub-courts.

CRITICAL RULES:
1. Audit the actual Flutter project, backend, and database before editing code.
2. Reuse existing screens, services, API endpoints, state management, and database fields.
3. Never rebuild from scratch or add duplicate tables/features.
4. Preserve customer app behavior and existing bookings.
5. Do not execute destructive migrations, production operations, refunds, or payouts.
6. Server is authoritative for availability, pricing, permissions, and payments.
7. Booking/tournament capacity must be concurrency-safe.
8. Do not invent status enums, endpoints, booking_mode values, or completed features.
9. If backend/customer app source is unavailable, document the gap and do not pretend to verify it.
10. Use the existing project's conventions unless a change is approved.

START WITH PHASE 0 ONLY:
- Inventory Flutter structure/screens/state/navigation/services.
- Inspect actual backend APIs and booking/payment logic if accessible.
- Inspect SQL schema, constraints, indexes, and existing migrations.
- Trace customer booking and owner booking compatibility.
- Produce the seven audit documents specified in Phase 0.
- Produce a prioritized task backlog with acceptance tests.
- Report what is already complete, partial, missing, or unverified.
- STOP and request my approval before changing application or database code.
```

---

## 23. PHASE-BY-PHASE CURSOR PROMPTS

### Prompt P1 — Foundation

```text
Read the KoCourt Partner master plan and approved Phase 0 audit. Implement Phase 1 only: owner auth/session, authorized venue selection, shared app navigation, state isolation across venue switches, consistent loading/error states. Reuse existing Flutter architecture. Before coding, show exact files and tests. After coding, run analysis/tests, update STATUS.md, and report regressions. Do not change booking/payment logic.
```

### Prompt P2 — Venue and facilities

```text
Read the master plan and audit. Implement Phase 2 in small PR-sized tasks. Use `courts` as venues and `sub_courts` as facilities. Reuse existing `capacity`, `booking_mode`, `hourly_rate`, photos, and owner relationships. Inspect actual enums/columns before writing code. Deliver venue list/detail/form, facility list/detail/form, and publication/verification states. Add no duplicate columns. Verify customer listing compatibility. Update tests and STATUS.md.
```

### Prompt P3 — Pricing, availability, blocks

```text
Implement Phase 3 after verifying existing pricing and blocked-slot code. Preserve pricing precedence unless an approved change is documented. Support venue/facility pricing, operating hours, exceptions, and blocks. Build backend availability tests for exclusive and shared-capacity facilities, including overnight slots and existing legacy bookings. Do not create an independent Flutter availability algorithm. Report exact migration needs before running them.
```

### Prompt P4 — Calendar and bookings

```text
Implement Phase 4 using the approved availability engine. Build day/week calendar, booking list/detail, walk-in and guest booking wizard, reschedule, cancel, check-in/no-show. Make server-side booking commits transactional and idempotent. Preserve existing booking statuses unless migration approved. Add concurrency tests and customer-app regression tests. Do not claim offline booking success without server confirmation.
```

### Prompt P5 — Finance and dashboard

```text
Implement Phase 5. Inspect existing payments, Cashfree-related fields, refunds, vendor profiles, and payouts. Reuse payment gateway integration. Add dashboard metrics and finance UI with separate gross, collected, refunded, commission, net and settled amounts. Verify webhook idempotency and authorization. Do not perform live payouts/refunds. Add reconciliation tests and document formulas.
```

### Prompt P6 — Tournaments

```text
Implement Phase 6. First propose event/organizer schema additions with migration and compatibility analysis. Support independent organizers without venue ownership, event/category wizard, individual/doubles/team registrations, approval/waitlist, payments, participant check-in, and shared court allocation. Ensure event reservations block conflicting public bookings. Add registration concurrency tests. Do not build advanced brackets until MVP is accepted.
```

### Prompt P7 — Memberships, staff, customers, analytics

```text
Implement Phase 7. First verify semantics of existing `plans` and `user_subscriptions`. Extend entitlements without duplication, create usage ledger only if required, enforce capacity on member bookings, implement venue-scoped customer directory and staff permissions, then reporting. Add tests for double redemption, cross-venue access, and financial report reconciliation. Update STATUS.md.
```

### Prompt P8 — Advanced features

```text
Implement Phase 8 only after core workflows are stable: tournament draws/matches/results, coaching/session scheduling, optional equipment rentals, accessibility, performance and UI polish. Feature-flag nonessential additions. Keep core booking API unchanged unless approved. Add integration tests and update documentation.
```

### Prompt P9 — Release hardening

```text
Execute Phase 9 readiness audit. Do not deploy without approval. Run static analysis, tests, build checks, concurrency tests, security/IDOR checks, migration rehearsal, customer-app regression, performance profiling, and incident/rollback review. Produce a release readiness report listing PASS, FAIL, NOT RUN with evidence and blocking issues. Stop for approval.
```

---

## 24. Progress tracking template

Create `docs/kocourt-partner/progress/STATUS.md`:

```markdown
# KoCourt Partner Development Status

## Current phase
Phase 0 — Audit

## Current task
Not started

## Completed with evidence
- None

## Partial
- None

## Blocked / missing access
- None documented

## Tests run
- Not run

## Schema changes
- None

## Customer app compatibility
- Not yet verified

## Next approved task
- Audit existing Flutter, backend, and schema

## Decisions requiring owner approval
- None yet
```

---

## 25. Final architectural decisions to preserve

1. **KoCourt** is the customer app; **KoCourt Partner** is the owner/organizer app.
2. **Venue → Facilities → Calendar → Bookings** is the primary owner mental model.
3. `courts` remains the venue table; `sub_courts` remains the facility table.
4. Mixed sports and mixed booking models are supported per facility.
5. Existing customer booking, payment, and social features must not regress.
6. Tournaments are organized by venue owners or independent organizers; KoCourt can sponsor but need not operate them.
7. One shared backend handles availability, pricing, payment, event allocation, and permissions.
8. Flutter implementation extends the existing project rather than replacing it.
9. Every phase is gated by tests and explicit review of potentially destructive changes.
10. The first Cursor action is an **audit, not code generation**.

**End of master plan.**
