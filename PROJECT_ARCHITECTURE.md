# KoCourt architecture and release contract

KoCourt is one marketplace with two clients: the Flutter mobile app in
`kocourt_flutter/` and the Vue web app in `frontend/`. Both use the PHP API in
`backend/` and MySQL. `public_html/` is the built Vue deployment artifact.

## Core domains

- Identity: OTP login, bearer token, standard users, and administrators.
- Marketplace: courts, spaces, discovery, map, favourites, claims and reviews.
- Reservations: availability, blocks, walk-ins, cancellations and recurring slots.
- Commerce: Cashfree orders, demo payments, memberships, owner earnings and admin ledger.
- Community: feed, comments, match requests, direct booking chat and slot groups.

## Client/API rules

1. New protected endpoints derive the user from the bearer token; do not trust a
   `user_id` supplied by either client. Venue access is determined by
   `courts.owner_id`, delegated `court_staff` access, or the `admin` role.
2. Flutter and Vue use the same canonical endpoint names. Add or change one only
   after updating `FEATURE_PARITY.md` and tests for the affected client.
3. Image uploads use `multipart/form-data` with an `image` field.
4. PUT/DELETE are tunneled as POST with `X-HTTP-Method-Override` for LiteSpeed.
5. Database migrations run through `Database::migrate`; controllers must never
   destructively change schemas.

## Production configuration

- `ALLOWED_ORIGINS` is a comma-separated browser-origin allow-list. The default
  permits the two KoCourt domains and Vite local development.
- Cashfree, SMS, database and deployment credentials live only in `backend/.env`.
- Deploy with an `X-Deploy-Key` HTTP header; never include the key in a URL.

## Automated release gate

GitHub Actions is the release gate. A clean checkout must pass PHP syntax,
Vue lint/build, analysis/tests and debug APK builds for both Flutter apps, then
the Player Flutter web build and Playwright E2E suite against a disposable MySQL
database. The web artifact is published only after every gate passes.

For staging reset, set `APP_ENV=staging` and a strong `E2E_RESET_KEY` in the
staging-only `backend/.env`, then run:

```sh
php backend/scripts/seed_e2e.php --key="$E2E_RESET_KEY"
```

The reset command refuses every environment except `test` and `staging`, and
requires the matching key. It must never be configured with production database
credentials.
