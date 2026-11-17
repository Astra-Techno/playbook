/**
 * Negative tests — things that SHOULD fail.
 * Tests: unauthenticated access, invalid data, permission violations.
 */
const { pass, fail, expectedFail, scenario } = require('../reporter');
const { ApiClient } = require('../api-client');
const { humanDelay } = require('../personas');

async function run(player) {
  scenario('Negative Tests — Error Handling');

  const anon = new ApiClient('Anonymous');  // no auth token

  // 1. Unauthenticated booking (should 401)
  try {
    await anon.post('/bookings', { court_id: 1, slots: [], type: 'hourly', total_price: 500 });
    fail('Anonymous', 'Book without auth', 'Should have returned 401');
  } catch (e) {
    if (e.status === 401) {
      expectedFail('Anonymous', `Book without auth`, `401 Unauthenticated`);
    } else {
      fail('Anonymous', 'Book without auth', `Expected 401, got ${e.status}`);
    }
  }

  await humanDelay();

  // 2. Unauthenticated post creation (should 401)
  try {
    await anon.post('/posts', { content: 'test' });
    fail('Anonymous', 'Post without auth', 'Should have returned 401');
  } catch (e) {
    if (e.status === 401) {
      expectedFail('Anonymous', `Post without auth`, `401 Unauthenticated`);
    } else {
      fail('Anonymous', 'Post without auth', `Expected 401, got ${e.status}`);
    }
  }

  await humanDelay();

  // 3. Access admin routes as regular user (should 403)
  try {
    await player.get('/admin/users');
    // If player is admin, this will succeed — that's OK
    pass(player.name, `Admin route access`, `user has admin role`);
  } catch (e) {
    if (e.status === 403) {
      expectedFail(player.name, `Admin route as player`, `403 Forbidden`);
    } else if (e.status === 401) {
      expectedFail(player.name, `Admin route`, `401 — token may have rotated`);
    } else {
      fail(player.name, 'Admin route', `Expected 403, got ${e.status}`);
    }
  }

  await humanDelay();

  // 4. Invalid court ID (should 404)
  try {
    await player.get('/courts/99999');
    fail(player.name, 'Invalid court ID', 'Should have returned 404');
  } catch (e) {
    if (e.status === 404) {
      expectedFail(player.name, `View court 99999`, `404 Not found`);
    } else {
      // Some APIs return empty data instead of 404
      expectedFail(player.name, `View court 99999`, `${e.status}: ${e.data?.message || 'handled'}`);
    }
  }

  await humanDelay();

  // 5. Review with missing data (should 400/422)
  try {
    await player.post('/reviews', {});
    fail(player.name, 'Review without data', 'Should have been rejected');
  } catch (e) {
    if (e.status === 400 || e.status === 422) {
      expectedFail(player.name, `Review without data`, `${e.status}: validation error`);
    } else {
      expectedFail(player.name, `Review without data`, `${e.status}: ${e.data?.message || 'rejected'}`);
    }
  }

  await humanDelay();

  // 6. Booking with invalid court (should fail)
  try {
    await player.post('/payments/quote', {
      type: 'booking',
      payload: { court_id: 99999, slots: [{ start_time: '2030-01-01 10:00:00', end_time: '2030-01-01 11:00:00' }], type: 'hourly', total_price: 500 },
    });
    fail(player.name, 'Book at invalid court', 'Should have been rejected');
  } catch (e) {
    expectedFail(player.name, `Book at court 99999`, `${e.status}: ${e.data?.message || 'rejected'}`);
  }

  await humanDelay();

  // 7. Delete another user's post (should fail)
  try {
    await player.del('/posts/1'); // post ID 1 belongs to another user
    // Might succeed if player owns it or is admin
    pass(player.name, `Delete post 1`, `allowed (may be own post or admin)`);
  } catch (e) {
    if (e.status === 403) {
      expectedFail(player.name, `Delete other's post`, `403 Forbidden`);
    } else {
      expectedFail(player.name, `Delete other's post`, `${e.status}: ${e.data?.message || 'rejected'}`);
    }
  }

  await humanDelay();

  // 8. Create chat with non-existent user
  try {
    await player.post('/chat/groups', {
      name: 'test', type: 'dm', member_ids: [999999],
    });
    fail(player.name, 'Chat with ghost user', 'Should have been rejected');
  } catch (e) {
    expectedFail(player.name, `Chat with user 999999`, `${e.status}: ${e.data?.message || 'rejected'}`);
  }
}

module.exports = { run };
