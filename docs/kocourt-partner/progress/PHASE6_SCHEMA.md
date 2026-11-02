# Phase 6 schema comparison

Written 2 Nov 2026. No tournament tables were created.

The customer plan and the Partner plan name the same records differently. One set of tables has to serve both apps. The names below are the customer plan’s names, because tournament discovery and registration are read by the customer app.

## Already in the backend

- `blocked_slots.block_kind` may be `tournament`. That is a closure label. It does not store an event, a category, or a registration.
- `booking_holds` reserves a court slot for 10 minutes during booking checkout. It is not a category seat hold.
- `court_staff` roles are `manager` and `viewer`. There is no organizer role.
- `users.role` is `user` or `admin`.
- Availability still counts confirmed bookings, active booking holds, and blocks. It does not know about events.

## One name for each record

| Record | Use this table | Partner plan also said | When |
|---|---|---|---|
| Event | `tournaments` | `events` | First migration, after this comparison is accepted |
| Entry class | `tournament_categories` | `event_categories` | With the event |
| Entry | `tournament_registrations` | `event_registrations` | With the event |
| Roster | `tournament_registration_members` | `event_teams`, `event_team_members` | With the event. One member row covers singles, doubles, and teams |
| Seat hold during registration | `tournament_capacity_holds` | none | With registration. Separate from `booking_holds` |
| Who may run the event | `tournament_organizers` | `event_organizers` | With the event. A user id and an event id. Do not copy `courts.owner_id` onto the organizer |
| Court time | existing `blocked_slots` | `event_resource_allocations`, `resource_reservations` | A later nullable `blocked_slots.tournament_id` once `tournaments` exists. A new reservation table waits until a block cannot express the closure |
| Arrival | `tournament_checkins` | `event_checkins` | After registration exists. Separate from `bookings.attendance` |
| Draws and scores | `tournament_matches`, `tournament_match_participants`, `tournament_results` | `event_matches`, `event_results` | Migration 029. A manual match of two confirmed entries. `POST .../bracket` writes Round 1 pairs in entry id order. An odd entry is a bye on that same round. When the latest round is fully scored, winners and byes are paired into the next round. One player left is the champion. |
| Follows, alerts, audit, external sources | `tournament_follows`, `tournament_alerts`, `tournament_audit_events`, `tournament_sources` | none | Only when a screen needs them |

## Rules that stay

- Publishing an event does not make the organizer the venue owner and does not grant staff rights on that venue.
- A court reservation for an event is a block the public booking check already sees. A second calendar is not added.
- `booking_holds` stays the checkout reserve. Category capacity uses `tournament_capacity_holds`.
- Registration states, when built, stay on the registration row. Booking status stays `pending`, `confirmed`, and `cancelled`.
- Play Circle tables in the customer plan are not part of this event set.

## Not done

`backend/migrations/022_tournaments.sql` creates the six tables. The API applies that file when the schema version moves to 26. It was not applied to a live database in the session that added it. There is no Partner screen yet. `POST /tournaments` saves a draft and an organizer row. It does not publish the event, open registration, or block a court.
