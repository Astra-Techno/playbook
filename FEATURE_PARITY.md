# Client feature-parity checklist

Use this checklist whenever changing the shared API. A tick means the capability
is exposed in the client, not merely supported by the backend.

| Domain | Vue web | Flutter |
| --- | --- | --- |
| OTP auth, profile, user/admin access | Yes | Yes |
| Venue discovery, filters, favourites, map | Yes | Yes |
| Available-now search | Yes | Partial — add the time-window UI before release |
| Booking, cancellation and payment | Yes | Yes |
| Recurring booking | Yes | API-ready — add the mobile flow before release |
| Add players / court regulars | Yes | API-ready — add the mobile flow before release |
| Memberships, payment history | Yes | Yes |
| Owner spaces, pricing, staff, calendar, earnings | Yes | Yes |
| Venue claims and image upload | Yes | Yes |
| Feed, matches and direct chat | Yes | Yes |
| Slot-group chat | API-ready | Yes |
| Admin claims and user list | Yes | Yes |
| Commercial settings administration (fees, tax, cancellation) | Yes - admin/settings | Web admin only |
| Server-priced checkout and accepted policy snapshot | Yes | Yes - Player/shared checkout |
| Automatic refunds and refund status | Yes - admin controls and customer history | Customer booking/payment history |

Commercial settings APIs: `GET/PUT /admin/settings`, `DELETE /admin/settings?court_id=ID`
(reset venue overrides), `GET /admin/refund-requests`, and `POST /payments/quote`.
Quote acceptance is required by `POST /payments/create-order`; deploy updated
clients with this backend. Existing mobile releases must be updated before paying.
Refund automation requires the v25 migration, CLI worker and Cashfree webhook configuration. Legacy records remain manual review. No deferred-settlement
execution is provided by this configuration release.

The three marked **API-ready** or **Partial** items are explicit mobile backlog,
not hidden backend functionality. Do not advertise platform parity until they are
implemented.
