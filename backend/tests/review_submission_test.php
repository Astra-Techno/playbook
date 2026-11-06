<?php

require_once __DIR__ . '/../src/ReviewSubmission.php';

function expect_review($label, $condition) {
    if (!$condition) {
        fwrite(STDERR, "FAIL $label\n");
        exit(1);
    }
    echo "PASS $label\n";
}

$ok = ReviewSubmission::fromBody([
    'court_id' => '12',
    'rating' => 5,
    'comment' => '  Great court  ',
]);
expect_review('string court id and rating are accepted', $ok['ok'] && $ok['court_id'] === 12 && $ok['rating'] === 5);
expect_review('comment is trimmed', $ok['comment'] === 'Great court');
expect_review('missing booking is omitted', $ok['booking_id'] === null);

$linked = ReviewSubmission::fromBody((object)[
    'courtId' => 4,
    'rating' => '4',
    'bookingId' => '9',
    'comment' => '',
]);
expect_review('camel case booking is kept', $linked['ok'] && $linked['booking_id'] === 9);

$bad = ReviewSubmission::fromBody(['court_id' => 3, 'rating' => 0]);
expect_review('rating is required', $bad['ok'] === false);

$empty = ReviewSubmission::fromBody(null);
expect_review('empty body is rejected', $empty['ok'] === false);

expect_review('my reviews do not need a court', ReviewSubmission::listScope(0, 0, true) === 'mine');
expect_review('a venue list still needs a court', ReviewSubmission::listScope(0, 0, false) === 'court_required');
expect_review('a court id lists that venue', ReviewSubmission::listScope(4, 0, true) === 'court');

echo "review submission ok\n";
