<?php

require_once __DIR__ . '/../src/TournamentPublish.php';

$failed = 0;
function check(bool $ok, string $message): void
{
    global $failed;
    if ($ok) {
        echo "ok  $message\n";
        return;
    }
    $failed++;
    fwrite(STDERR, "FAIL $message\n");
}

$open = TournamentPublish::plan('draft', null, null, null, true);
check($open['ok'] === true && $open['block'] === false, 'an event without a venue publishes with no court closure');

$close = TournamentPublish::plan('draft', 4, '2026-12-01 09:00:00', '2026-12-01 18:00:00', true);
check($close['ok'] === true && $close['block'] === true, 'a venue and a time range close the court');

$busy = TournamentPublish::plan('draft', 4, '2026-12-01 09:00:00', '2026-12-01 18:00:00', false);
check($busy['ok'] === false, 'a busy venue stays a draft');

$half = TournamentPublish::plan('draft', null, '2026-12-01 09:00:00', null, true);
check($half['ok'] === false, 'a start without an end is refused');

$order = TournamentPublish::plan('draft', 4, '2026-12-01 18:00:00', '2026-12-01 09:00:00', true);
check($order['ok'] === false, 'an end before the start is refused');

$again = TournamentPublish::plan('published', 4, '2026-12-01 09:00:00', '2026-12-01 18:00:00', true);
check($again['ok'] === false, 'a published event is not published again');

$back = TournamentPublish::unpublish('published');
check($back['ok'] === true, 'a published event can return to a draft');

$still = TournamentPublish::unpublish('draft');
check($still['ok'] === false, 'a draft is not unpublished again');

if ($failed > 0) {
    fwrite(STDERR, "$failed failed\n");
    exit(1);
}
echo "all passed\n";
