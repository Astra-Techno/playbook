# Commercial configuration

Open **Admin > Commercial Settings** (`/admin/settings`) in the Vue app.
The existing `config` table is the single commercial policy store. The v25
`Database::migrate` migration adds the policy defaults, audit history, payment and
booking snapshots, the refund outbox and refund audit events. No controller creates tables.

## Keys and scope

`config.key = commerce_policy` contains a typed JSON object. Per-venue overrides
are stored at `commerce_policy.venue.<court_id>`. Use the admin form/API rather
than editing the JSON or the legacy `platform_commission_pct` key. Existing
commission configuration is preserved at migration, including zero. Explicit
per-vendor commission overrides still take precedence for Cashfree splits.

The form exposes company GST status/GSTIN, checkout availability, advance/notice
windows, fixed or percentage platform fees, inclusive/exclusive platform-fee GST,
venue tax rate and inclusive/exclusive pricing, cancellation/refund tiers,
platform-fee refund treatment, refund-time estimates, Easy Split and commission,
and processing-cost estimates. Venue GST registration and GSTIN must be entered
per venue. Saving a venue pins its displayed tax, booking and cancellation
settings; use **Use platform defaults** to remove those overrides.

Fee percentage uses the tax-inclusive venue charge. Fixed fees apply once per
checkout, not once per slot. GST is calculated only when the relevant supplier
is marked registered. GSTIN checks validate format only. Select the legally
appropriate rate for the specific service; no automatic legal classification,
GST registration verification, tax return, TCS deduction or tax remittance occurs.
No GST or platform fee is enabled by default. Cancellation defaults are 12-hour
full refund, 6-hour 50% venue refund and 0% later; review before going live.
Zero maximum advance hours means unlimited, not a 48-hour booking limit.

Processing rates calculate an estimate recorded in the payment snapshot only.
They do not deduct costs from a venue, change Cashfree's actual charges, or
determine who contractually bears those charges. Venue commission is separate
from the customer platform fee; verify both before enabling fees.

## Checkout and cancellation

The web and shared Flutter payment flows obtain `POST /payments/quote`, display
the price breakdown and policy, then send its `quote_hash` when creating the
order. Prices, plan duration and access type come from the server. Stale quotes
are rejected. Monetary arithmetic is in paise, with exact per-slot allocation.
Accepted settings and price components are saved with payments and bookings.
Changing settings never recalculates the cancellation terms for those bookings.

Customer cancellation uses the booking's original tiers. Venue/staff/admin
cancellation of someone else's booking makes the full paid amount eligible.
The cancellation and insertion of its refund-review request are atomic, with one
refund request per booking. Legacy bookings lacking snapshots require manual
review of their original terms and amount. Cancelled bookings remain in history.

Eligible cancellations reserve a refund in the same transaction that releases the
slot. Each new booking points directly to its payment; the original Cashfree
mode, environment and split instructions are saved on the payment. Legacy
payments without this metadata remain manual and are never guessed or backfilled.
A payment-wide lock and integer-paise budgets prevent requests exceeding the
original venue charge, fee, total or vendor allocation. Fixed fees are allocated
across slots once; unfulfilled slots receive their allocated venue charge and fee.

New paid bookings that cannot be fulfilled (including partial slot failures) and
failed subscription activation enqueue the unfulfilled amount. Exceptions during
fulfilment roll back its writes, then attempt a separate full-refund reservation
only if another verifier has not already fulfilled the payment. A database outage
can still require retrying verification or manual support; do not promise refunds
when the payment/outbox could not be persisted.

Refund submission uses a stable refund ID, persisted body and UUID idempotency
key. Before submission, the worker checks the original order, existing refund and
provider refund list. An unknown dashboard refund stops automatic submission.
Easy Split refund amounts use the original vendor allocation in proportion to the
venue component, including an explicit zero vendor debit on fee-only refunds.
Cashfree may require additional account funding or vendor recovery; rejections,
missing credentials, environment mismatches and unsupported records go to review.

Only provider-confirmed `SUCCESS` counts as refunded. `PENDING`, approval and
on-hold responses are polled; ambiguous network failures retry the same ID/body.
Terminal failures are not automatically reissued. Submission attempts, status
checks, delays, automatic amount limit and maximum pending age are configurable.
A lease prevents overlapping workers handling the same request. Signed webhook
payloads trigger a provider GET, never a refund POST; duplicate payloads are
recorded. Refund events and customer inbox updates track terminal/review changes.

Customers see current refund states in web/mobile history. Admins can check
Cashfree or explicitly submit an approved request in Commercial Settings. Enabling
automation does not process historical manual-review records automatically.
Simulated refunds make no provider requests. Confirmed refunds are subtracted
from payment-based owner summaries and appear as separate ledger debits. Existing
venue booking reports remain booking-based; these are not settlement statements.
No tax credit note, GST return, refund of Cashfree processing fees, or automatic
settlement hold is implemented.

Easy Split uses the existing immediate order-split integration and active vendor
profile. A missing active vendor means no split is added, as before. Disabling
split sends no vendor instructions; it does not pause collection or arrange a
later payout. Deferred settlements require separate Cashfree approval and
implementation. No setting silently promises that unsupported capability.

Secrets (API keys, database credentials) are outside this public commercial
schema; `/payments/config` never exposes those secrets. Existing legacy admin
configuration and environment configuration remain separate operational tools.

## API and deployment

- `GET /admin/settings[?court_id=ID]`: admin-only values, schema, revision, history.
- `PUT /admin/settings[?court_id=ID]`: `{values: {...}, revision: "..."}`;
  all settings are validated together, writes are audited, stale edits return 409.
- `DELETE /admin/settings?court_id=ID`: `{revision: "..."}` removes venue overrides.
- `GET /admin/refund-requests`: recent canonical and legacy review records, admin only.
- `POST /admin/refund-requests/:id/submit`: explicitly approve a persisted request.
- `POST /admin/refund-requests/:id/sync`: check provider status without submission.
- `GET /payments/refunds`: authenticated customer refund history.
- `POST /payments/refund-webhook`: Cashfree-signed public webhook endpoint.
- `GET /payments/config[?court_id=ID]`: payment environment plus effective policy.
- `POST /payments/quote`: authenticated `{type, payload}`; returns amount, hash,
  snapshot and cost estimate. `POST /payments/create-order` requires that hash.

Deploy the backend and new web/mobile clients together. Old mobile builds cannot
create orders without quote acceptance. New web demo checkouts use the same
quote/order/verification flow as real payments, with simulated collection.
Owner/manager walk-ins keep their existing manual flow. Positive-price customer
bookings and paid plan purchases/renewals must use checkout. Free plans retain
their direct flow, and admins can still record plan grants manually.

Run isolated checks:

```sh
php backend/tests/commerce_settings_test.php
php backend/tests/commerce_checkout_test.php
php backend/tests/commerce_cancellation_test.php
php backend/tests/refund_service_test.php
```

The checkout test uses SQLite memory fixtures; it never resets a live database.
Run the v25 MySQL migration and end-to-end Cashfree sandbox verification in
staging before production. Gateway credentials are not needed for the unit tests.

## Activate automatic refunds on hosting

1. Deploy the backend and clients together, take a database backup, and verify the
   v25 migration on staging first. New columns/tables are additive; no existing
   payments or bookings are rewritten. MySQL integration still requires staging
   verification; automated tests use isolated SQLite fixtures.
2. Configure Cashfree sandbox credentials and `cashfree_env=sandbox` using the
   existing operational config. Test collection, full/partial cancellation,
   unfulfilled slots and Easy Split vendor recovery in your own Cashfree account.
3. Configure the Cashfree refund status webhook to
   `https://www.kocourt.com/api/payments/refund-webhook`. Keep its raw request body
   and `x-webhook-timestamp` / `x-webhook-signature` headers intact through the
   proxy. The HMAC uses the configured Cashfree secret. Subscribe to refund status
   events offered for your account/API version. The worker also reconciles if a
   webhook is missed. Do not expose API credentials in frontend or cron URLs.
4. Schedule CLI cron every minute (replace paths with your hosting paths):

   ```cron
   * * * * * /usr/bin/php /home/ACCOUNT/playbook/backend/bin/process_refunds.php >> /home/ACCOUNT/logs/kocourt-refunds.log 2>&1
   ```

   This script refuses HTTP execution. Overlapping cron runs are protected by
   per-request leases. Monitor cron failures and the review queue; a stopped
   worker delays refunds. New requests also attempt immediate processing after
   the booking transaction commits.
5. In **Admin > Commercial Settings > Refund automation**, choose the automatic
   limit, attempt/check limits and delays, then enable automatic refunds. Defaults:
   disabled, INR 10,000 cap, five submissions, 672 checks, five-minute retry,
   15-minute polling, seven-day pending escalation. Turning submission off still
   allows already attempted refunds to reconcile. Explicit admin approval can
   submit over the automatic limit, but cannot bypass payment/split validation.
6. After sandbox verification, configure production credentials/environment and
   webhook, then validate a controlled production payment/refund. Requests retain
   their original environment and will never be submitted using the other one.
   Resolve sandbox requests before switching the single-environment deployment.

Official API references: [create refund](https://www.cashfree.com/docs/api-reference/payments/latest/refunds/create-refund),
[get refund](https://www.cashfree.com/docs/api-reference/payments/latest/refunds/get-refund),
[webhook signatures](https://www.cashfree.com/docs/payments/online/webhooks/signature-verification).
The application retains its configured Cashfree API version; these links describe
the current documentation. Confirm enabled Easy Split behavior in sandbox.
