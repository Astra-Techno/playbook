# Test targets

`npm run test:smoke` checks the deployed Vue site and public courts API using
GET requests only. CI passes `E2E_BASE_URL` and `E2E_API_BASE_URL` for the live
deployment. These checks do not establish full booking/payment feature coverage
or validate the current checkout before deployment.

`npm test -- kocourt.spec.js` runs the full integration suite, including account,
booking and payment mutations. Run it only against an isolated test/staging
deployment with the appropriate test accounts and fixtures. Do not point it at
production. Updating a deployed site's login rules or fixture data requires
updating that suite's assumptions too; production authentication must not be
relaxed to make a demo OTP test pass.

The live Vue website does not have Flutter canvas elements. Flutter web visual
tests require a separate Flutter web build and URL.
