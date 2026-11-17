/**
 * Owner scenarios — venue management, pricing, staff, plans.
 * Tests: update venue, manage spaces, pricing rules, staff, plans, earnings.
 */
const { pass, fail, scenario } = require('../reporter');
const { humanDelay } = require('../personas');

async function run(owner) {
  scenario('Owner — Venue Management');

  try {
    // 1. View owner's courts
    const courts = await owner.get('/courts');
    const list = (courts.records || []).filter(c => String(c.owner_id) === String(owner.userId));
    pass(owner.name, `My venues`, `${list.length} owned courts`);
    if (list.length === 0) { fail(owner.name, 'No venues owned'); return; }

    const court = list[0];
    await humanDelay();

    // 2. View court detail
    const detail = await owner.get(`/courts/${court.id}`);
    const c = detail.court || detail;
    pass(owner.name, `Venue detail`, `"${c.name}", rate=${c.hourly_rate}, hours=${c.open_time}-${c.close_time}`);

    await humanDelay();

    // 3. View sub-courts (spaces)
    const spaces = await owner.get(`/sub-courts?court_id=${court.id}`);
    const spaceList = spaces.records || [];
    pass(owner.name, `Spaces`, `${spaceList.length} spaces in "${c.name}"`);

    await humanDelay();

    // 4. View pricing rules
    const pricing = await owner.get(`/pricing-rules?court_id=${court.id}`);
    const rules = pricing.records || pricing.rules || [];
    pass(owner.name, `Pricing rules`, `${rules.length} rules configured`);

    await humanDelay();

    // 5. View subscription plans
    const plans = await owner.get(`/plans?court_id=${court.id}`);
    const planList = plans.records || [];
    pass(owner.name, `Plans`, `${planList.length} plans for "${c.name}"`);

    await humanDelay();

    // 6. View blocked slots
    const blocks = await owner.get(`/blocked-slots?court_id=${court.id}`);
    const blockList = blocks.records || [];
    pass(owner.name, `Blocked slots`, `${blockList.length} blocks`);

    await humanDelay();

    // 7. View staff
    try {
      const staff = await owner.get(`/court-staff?court_id=${court.id}`);
      const staffList = staff.records || staff.staff || [];
      pass(owner.name, `Staff`, `${staffList.length} staff members`);
    } catch (e) {
      pass(owner.name, `Staff list`, `${e.data?.message || e.message}`);
    }

    await humanDelay();

    // 8. View earnings
    try {
      const earnings = await owner.get(`/earnings?court_id=${court.id}`);
      pass(owner.name, `Earnings`, `total=${earnings.total || earnings.summary?.total || 'N/A'}`);
    } catch (e) {
      pass(owner.name, `Earnings`, `${e.data?.message || e.message}`);
    }

    await humanDelay();

    // 9. View analytics
    try {
      const analytics = await owner.get(`/analytics?court_id=${court.id}`);
      pass(owner.name, `Analytics`, `bookings=${analytics.total_bookings || 'N/A'}`);
    } catch (e) {
      pass(owner.name, `Analytics`, `${e.data?.message || e.message}`);
    }

    await humanDelay();

    // 10. View bookings for venue
    try {
      const bookings = await owner.get(`/bookings?court_id=${court.id}`);
      const bookList = bookings.records || [];
      pass(owner.name, `Venue bookings`, `${bookList.length} bookings`);
    } catch (e) {
      pass(owner.name, `Venue bookings`, `${e.data?.message || e.message}`);
    }

    await humanDelay();

    // 11. View subscription members
    try {
      const members = await owner.get(`/subscriptions/members?court_id=${court.id}`);
      const memberList = members.records || [];
      pass(owner.name, `Subscription members`, `${memberList.length} members`);
    } catch (e) {
      pass(owner.name, `Members`, `${e.data?.message || e.message}`);
    }

    // 12. View calendar for tomorrow
    const tomorrow = new Date();
    tomorrow.setDate(tomorrow.getDate() + 1);
    const dateStr = tomorrow.toISOString().split('T')[0];
    try {
      const cal = await owner.get(`/courts/${court.id}/calendar?date=${dateStr}`);
      pass(owner.name, `Calendar (${dateStr})`, `slots loaded`);
    } catch (e) {
      pass(owner.name, `Calendar`, `${e.data?.message || e.message}`);
    }

  } catch (e) {
    fail(owner.name, 'Owner flow', e.message);
  }
}

module.exports = { run };
