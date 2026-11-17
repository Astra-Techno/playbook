# KoCourt - Sports Venue Booking Platform

## What is this?
A full-stack sports court booking platform with three client apps sharing a PHP API backend.

| Component | Stack | Location |
|-----------|-------|----------|
| Vue Web App | Vue 3, Vite, Tailwind CSS, Pinia | `frontend/` |
| Player App | Flutter (Android/iOS) | `kocourt_flutter/` |
| Owner App | Flutter (Android/iOS) | `kocourt_owner/` |
| Shared Dart Package | Provider, Dio, GoRouter | `kocourt_shared/` |
| API Backend | PHP 8.3, PDO, MySQL | `backend/` |
| Live Site | | https://www.kocourt.com |

## Architecture

### Backend (backend/)
- **Single-file router** (`index.php`) - manual URL segmentation, no framework
- **33 controllers** in `src/Controllers/` - each handles one domain (Auth, Court, Booking, Payment, Tournament, Chat, etc.)
- **39 service classes** in `src/` - business logic (Commerce, Refund, Tournament, Coaching, Equipment, etc.)
- **Auth**: Phone -> OTP (Ping4sms, demo=1234) -> 64-char hex bearer token stored in `users.auth_token`
- **DB**: MySQL, auto-migrated via `config/database.php` (schema v36, 50+ tables, 34 migration files in `migrations/`)
- **Payments**: Cashfree PG (quote -> review -> order -> SDK -> verify), demo mode if credentials missing
- **User ID always derived from token** on backend, never from request body

### Vue Frontend (frontend/)
- **45 views**, 13 sheet components, 3 Pinia stores (auth, notifications, toast)
- **55+ routes** with guards: requiresAuth, requiresAdmin, guestOnly, hideHeader, hideBottomNav, fullScreen
- **Mobile-first** layout (max-width 430px), frosted glass header, 5-tab bottom nav
- Dev: `npm run dev` proxies `/api/*` to localhost backend
- Prod: requests go to `/backend` directly

### Flutter Apps
- **Player** (`kocourt_flutter/`): 40 screens, 60 routes - book courts, chat, matches, feed, subscriptions
- **Owner** (`kocourt_owner/`): 50+ screens, 40+ routes - manage venues, staff, pricing, earnings, tournaments, coaching, equipment
- **Shared** (`kocourt_shared/`): 4 providers (Auth, Venue, Toast, Notifications), PaymentService, theme, icons, widgets
- State: Provider (ChangeNotifier), Routing: GoRouter, HTTP: Dio with method tunneling

## Key Patterns

### Method Tunneling (LiteSpeed workaround)
DELETE/PUT/PATCH requests are sent as POST with `X-HTTP-Method-Override` header. Backend reads this header to determine actual method.

### Commerce Checkout Flow
1. `POST /payments/quote` - get price breakdown (venue, fee, tax)
2. User reviews terms in dialog
3. `POST /payments/create-order` - create Cashfree order (or demo order)
4. Cashfree SDK opens payment page (skipped in demo mode)
5. `POST /payments/verify` - confirm payment, create booking/subscription

### Chat System
WhatsApp-style group chat with connection-based restrictions. Users can only message people they're connected with (co-players, venue members, match partners, post interactions). 5-second polling, no WebSocket.

### Schema Migrations
Additive-only SQL migrations in `backend/migrations/`. Each ALTER wrapped in try/catch for idempotency. Version tracked in `schema_version` table. Runs automatically on deploy.

## Coding Conventions

### PHP Backend
- Controllers return JSON via `echo json_encode()` + `exit()`
- Auth guards: `Auth::require()` (any user), `Auth::requireAdmin()` (admin only), `Auth::requireOwner()` (alias for require)
- Venue ownership by `courts.owner_id`, staff access by `court_staff` table - NOT by user role
- Database queries use PDO prepared statements exclusively
- New features get their own controller file + service class

### Vue Frontend
- `<script setup>` with Composition API everywhere
- Axios with global Authorization header set from localStorage
- CSS utility classes: `.btn-primary`, `.btn-secondary`, `.input-field`, `.card`, `.badge`, `.page-gutter` (px-5), `.glass-blur`
- Colors: primary `#a93100` (terracotta), secondary `#006e29` (green)
- Icons: lucide-vue-next
- Teleport pattern: child views inject into `#header-subtitle`, `#header-action`, `#header-extra` DOM slots

### Flutter
- Provider + ChangeNotifier for state
- GoRouter with refreshListenable(authProvider) for reactive auth redirects
- Dio with method tunneling interceptor (same as Vue)
- Colors: primary `#E23D28`, secondary `#1B8C3D`
- Icons: Material Icons mapped from Lucide names via `kocourt_shared/core/icons.dart`
- Inline `Map<String,dynamic>` models (no model classes)
- `if (mounted)` guard after every async gap in StatefulWidgets
- `context.read<Provider>()` before `await` to avoid BuildContext across async gaps

## CI/CD

### build.yml (every push to main)
1. **Vue quality**: lint + build
2. **Flutter builds**: analyze + test + build APK (release, both apps)
3. **PHP check**: syntax check + commerce tests
4. **Publish**: commit built `public_html/` + APKs with `[skip ci]`

### ios.yml (manual or PR)
- Builds iOS on macOS-15 runner
- Optional TestFlight upload via `upload_testflight` input

### Deployment
- `deploy.php` authenticates via `X-Deploy-Key` header
- Downloads GitHub ZIP, copies backend (preserves .env), copies public_html, runs SQL migrations
- Trigger from kocourt.com/apps admin page or via curl

## Testing
- **Flutter**: Unit tests in each app's `test/` directory
- **PHP**: Integration tests in `backend/tests/` (run in CI)
- **E2E**: Playwright against live kocourt.com (currently disabled in CI)
- **E2E auth**: Demo OTP mode (code=1234), admin phone 9994439081

## External Services
| Service | Purpose | Config |
|---------|---------|--------|
| Cashfree PG | Payments + Refunds | CASHFREE_APP_ID/SECRET_KEY/ENV in .env |
| Ping4sms | OTP SMS | PING4SMS_KEY/SENDER/TEMPLATE_ID in .env |
| Google Places | Court photos + search | GOOGLE_PLACES_API_KEY in .env |
| MapmyIndia | India nearby places | MAPMYINDIA_* in .env |
| Firebase FCM | Push notifications | FCM_SERVER_KEY in .env |
| AppifyWeb24 | Android WebView wrapper | window.SaaS bridge in frontend |
| Nominatim | Reverse geocode | No key needed |
| Overpass | OSM nearby fallback | No key needed |

## Common Tasks

### Add a new API endpoint
1. Create/edit controller in `backend/src/Controllers/`
2. Add route in `backend/index.php` with appropriate Auth guard
3. If new table needed, add migration SQL to `backend/migrations/`

### Add a new Vue page
1. Create view in `frontend/src/views/`
2. Add route in `frontend/src/router/index.js` with meta flags
3. If auth-gated, add `meta: { requiresAuth: true }`

### Add a new Flutter screen
1. Create screen in `kocourt_flutter/lib/screens/` or `kocourt_owner/lib/screens/`
2. Add route in `lib/core/router.dart`
3. Use `kocourt_shared` providers/services for API calls

### Deploy changes
1. Push to `main` branch
2. CI builds + commits artifacts
3. Hit deploy endpoint: `curl -H "X-Deploy-Key: KEY" https://www.kocourt.com/deploy.php`
4. Or use kocourt.com/apps admin page "Deploy to Live" button
