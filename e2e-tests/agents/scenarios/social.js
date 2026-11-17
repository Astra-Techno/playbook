/**
 * Social scenarios — posts, likes, comments, matches.
 * Tests: create post, like/unlike, comment, create match, join match.
 */
const { pass, fail, scenario } = require('../reporter');
const { humanDelay } = require('../personas');

async function run(player1, player2) {
  scenario('Social — Posts, Likes, Comments, Matches');

  let postId;

  try {
    // 1. Player 1 creates a post
    const postContent = `[TEST] Great session today! ${Date.now()}`;
    const post = await player1.post('/posts', { content: postContent });
    postId = post.id || post.post?.id;
    pass(player1.name, `Created post`, `id=${postId}`);

    await humanDelay();

    // 2. Verify post appears in feed
    const feed = await player1.get('/posts');
    const posts = feed.records || [];
    const found = posts.find(p => String(p.id) === String(postId));
    if (found) {
      pass(player1.name, `Post visible in feed`, `"${found.content?.slice(0, 40)}..."`);
    } else {
      fail(player1.name, `Post visible in feed`, `post ${postId} not found`);
    }

    await humanDelay();

    // 3. Player 2 likes the post
    await player2.post(`/posts/${postId}/like`);
    pass(player2.name, `Liked post ${postId}`);

    await humanDelay();

    // 4. Player 2 comments on the post
    const commentText = `[TEST] Nice one! ${Date.now()}`;
    await player2.post(`/posts/${postId}/comment`, { content: commentText });
    pass(player2.name, `Commented on post ${postId}`);

    await humanDelay();

    // 5. Player 1 views post detail — should show like + comment
    const detail = await player1.get(`/posts/${postId}`);
    const p = detail.post || detail;
    pass(player1.name, `Post detail`, `likes=${p.likes_count}, comments=${p.comment_count || p.comments?.length}`);

    await humanDelay();

    // 6. Player 2 unlikes the post
    await player2.post(`/posts/${postId}/like`); // toggle
    pass(player2.name, `Unliked post ${postId}`);

  } catch (e) {
    fail(player1.name, 'Social — Posts flow', e.message);
  }

  // === Match Requests ===
  let matchId;
  try {
    await humanDelay();

    // 7. Get a court for match
    const courts = await player1.get('/courts');
    const court = (courts.records || [])[0];
    if (!court) { fail(player1.name, 'No court for match'); return; }

    // 8. Player 1 creates a match request
    const tomorrow = new Date();
    tomorrow.setDate(tomorrow.getDate() + 2);
    const dateStr = tomorrow.toISOString().split('T')[0];
    const match = await player1.post('/match-requests', {
      court_id: court.id,
      sport: court.type || 'shuttle',
      date: dateStr,
      play_time: '18:00',
      skill_level: 'intermediate',
      max_players: 4,
      description: `[TEST] Looking for players ${Date.now()}`,
    });
    matchId = match.id || match.match?.id;
    pass(player1.name, `Created match request`, `id=${matchId} at "${court.name}"`);

    await humanDelay();

    // 9. Player 2 views open matches
    const openMatches = await player2.get('/match-requests');
    const matchList = openMatches.requests || [];
    pass(player2.name, `Viewed open matches`, `${matchList.length} available`);

    await humanDelay();

    // 10. Player 2 joins the match
    if (matchId) {
      await player2.post(`/match-requests/${matchId}/join`);
      pass(player2.name, `Joined match ${matchId}`);

      await humanDelay();

      // 11. Player 2 leaves the match
      await player2.del(`/match-requests/${matchId}/leave`);
      pass(player2.name, `Left match ${matchId}`);
    }

  } catch (e) {
    fail(player1.name, 'Social — Matches flow', e.message);
  }

  // === Cleanup ===
  try {
    if (postId) {
      await player1.del(`/posts/${postId}`);
      pass(player1.name, `Cleaned up post ${postId}`);
    }
    if (matchId) {
      await player1.del(`/match-requests/${matchId}`);
      pass(player1.name, `Cleaned up match ${matchId}`);
    }
  } catch (e) {
    // Cleanup failures are non-critical
  }
}

module.exports = { run };
