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

The three marked **API-ready** or **Partial** items are explicit mobile backlog,
not hidden backend functionality. Do not advertise platform parity until they are
implemented.
