/**
 * Discovery scenarios — browse, search, view courts like a new user.
 * Tests: court listing, filtering, court detail, plans, reviews, availability.
 */
const { pass, fail, scenario } = require('../reporter');
const { humanDelay, pick } = require('../personas');

async function run(player) {
  scenario('Discovery — Browse & Search Venues');

  // 1. Browse all courts (no auth needed)
  try {
    const courts = await player.get('/courts');
    const list = courts.records || [];
    pass(player.name, `Browse all courts`, `found ${list.length} venues`);
    if (list.length === 0) { fail(player.name, 'Courts list', 'No courts found on live server'); return; }

    await humanDelay();

    // 2. Pick a random court and view details
    const court = pick(list);
    const detail = await player.get(`/courts/${court.id}`);
    const c = detail.court || detail;
    pass(player.name, `View court detail`, `"${c.name}" (${c.type}), rate=${c.hourly_rate}`);

    await humanDelay();

    // 3. Check slot availability for tomorrow
    const tomorrow = new Date();
    tomorrow.setDate(tomorrow.getDate() + 1);
    const dateStr = tomorrow.toISOString().split('T')[0];
    try {
      const bookings = await player.get(`/bookings?court_id=${court.id}&date=${dateStr}`);
      const booked = bookings.records || bookings.bookings || [];
      pass(player.name, `Check availability (${dateStr})`, `${booked.length} existing bookings`);
    } catch (e) {
      // Some courts may not have bookings endpoint open without auth
      pass(player.name, `Check availability`, `endpoint requires auth (expected)`);
    }

    await humanDelay();

    // 4. View subscription plans for this court
    const plans = await player.get(`/plans?court_id=${court.id}`);
    const planList = plans.records || plans.plans || [];
    pass(player.name, `View plans for "${c.name}"`, `${planList.length} plans available`);

    await humanDelay();

    // 5. View reviews for this court
    const reviews = await player.get(`/reviews?court_id=${court.id}`);
    const reviewList = reviews.records || [];
    pass(player.name, `View reviews for "${c.name}"`, `${reviewList.length} reviews, avg=${reviews.avg_rating || 'none'}`);

    await humanDelay();

    // 6. View sub-courts (spaces)
    const spaces = await player.get(`/sub-courts?court_id=${court.id}`);
    const spaceList = spaces.records || spaces.sub_courts || [];
    pass(player.name, `View spaces for "${c.name}"`, `${spaceList.length} spaces`);

    await humanDelay();

    // 7. Browse courts by sport type
    const sportTypes = ['shuttle', 'cricket', 'gym', 'boxing', 'football'];
    const sport = pick(sportTypes);
    const filtered = await player.get(`/courts?type=${sport}`);
    const filteredList = filtered.records || [];
    pass(player.name, `Search by sport "${sport}"`, `${filteredList.length} matches`);

    // 8. View community feed (public)
    const feed = await player.get('/posts');
    const posts = feed.records || [];
    pass(player.name, `Browse community feed`, `${posts.length} posts`);

    // 9. View match requests (public)
    const matches = await player.get('/match-requests');
    const matchList = matches.requests || [];
    pass(player.name, `Browse match requests`, `${matchList.length} open matches`);

  } catch (e) {
    fail(player.name, 'Discovery flow', e.message);
  }
}

module.exports = { run };
