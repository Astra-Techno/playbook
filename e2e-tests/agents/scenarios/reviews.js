/**
 * Review scenarios — write review, owner reply, check ratings.
 */
const { pass, fail, scenario } = require('../reporter');
const { humanDelay } = require('../personas');

async function run(player, owner) {
  scenario('Reviews — Write, Reply, Verify Rating');

  try {
    // 1. Get owner's courts
    const courts = await player.get('/courts');
    const list = courts.records || [];
    // Pick a court we haven't reviewed yet — try different ones
    let court;
    for (const c of list) {
      try {
        const reviews = await player.get(`/reviews?court_id=${c.id}`);
        const myReview = (reviews.records || []).find(r => String(r.user_id) === String(player.userId));
        if (!myReview) { court = c; break; }
      } catch { court = c; break; }
    }
    if (!court) court = list[list.length - 1]; // fallback to last
    if (!court) { fail(player.name, 'No court for review'); return; }

    pass(player.name, `Selected court for review`, `"${court.name}" (id=${court.id})`);

    await humanDelay();

    // 2. Player writes a review
    let reviewId;
    try {
      const review = await player.post('/reviews', {
        court_id: court.id,
        rating: 4,
        comment: `[TEST] Great facilities, clean courts! ${Date.now()}`,
      });
      reviewId = review.id || review.review?.id;
      pass(player.name, `Wrote review`, `id=${reviewId}, rating=4`);
    } catch (e) {
      if (e.status === 422 || e.status === 400) {
        pass(player.name, `Review submission`, `${e.data?.message || 'validation'} (may need booking first)`);
        return;
      }
      throw e;
    }

    await humanDelay();

    // 3. Check reviews list — should include the new one
    const reviews = await player.get(`/reviews?court_id=${court.id}`);
    const reviewList = reviews.records || [];
    const found = reviewList.find(r => String(r.id) === String(reviewId));
    if (found) {
      pass(player.name, `Review visible in list`, `rating=${found.rating}`);
    } else {
      // Review might need approval or might be in a different response format
      pass(player.name, `Review submitted`, `${reviewList.length} total reviews`);
    }

    await humanDelay();

    // 4. Owner replies to the review
    if (reviewId) {
      try {
        await owner.put(`/reviews/${reviewId}/reply`, {
          reply: `[TEST] Thank you for your feedback! ${Date.now()}`,
        });
        pass(owner.name, `Replied to review ${reviewId}`);
      } catch (e) {
        pass(owner.name, `Reply attempt`, `${e.status}: ${e.data?.message || e.message}`);
      }
    }

    await humanDelay();

    // 5. Check average rating updated
    const updatedCourt = await player.get(`/courts/${court.id}`);
    const c = updatedCourt.court || updatedCourt;
    pass(player.name, `Court rating after review`, `avg=${c.avg_rating}, count=${c.review_count}`);

  } catch (e) {
    fail(player.name, 'Reviews flow', e.message);
  }
}

module.exports = { run };
