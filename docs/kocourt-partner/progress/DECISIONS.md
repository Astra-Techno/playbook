# Decisions waiting for approval

Phase 0 and P1-T1 were approved on 31 October 2026. The defaults below still stand.

1. **Keep the current shell.** Tabs stay Venues, Bookings, Earnings, Chat, Profile. The plan’s Home / Calendar / Facilities / Events / More layout is a later navigation change, not Phase 1.
2. **Keep the current brand in code.** Title stays KoCourt Owner. Primary color stays `#E23D28`. Partner green is not applied just to match the plan.
3. **Keep table and route names.** `courts` are venues in conversation, `sub-courts` are spaces in the UI. No rename migration.
4. **Keep booking statuses and booking modes.** Status stays `pending`, `confirmed`, `cancelled`. Mode stays `exclusive` and `shared`.
5. **Phase 1 code scope** is staff venues on the dashboard, honest loading and error states, and a router test. No booking, payment, or SQL changes.
6. **Plans stay peak-hour memberships** until a separate pass defines package credits.
7. **Tournament tables are not designed in the Partner repo alone.** The customer plan uses different table names for the same idea. One schema, agreed later.
