<?php

require_once __DIR__ . '/../src/TournamentAnnouncement.php';

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

$note = TournamentAnnouncement::fromInput(['title' => ' Gates ', 'body' => ' Use gate B. ']);
check($note['ok'] === true && $note['title'] === 'Gates' && $note['body'] === 'Use gate B.', 'a title and a message are kept');
check(TournamentAnnouncement::fromInput(['title' => '', 'body' => 'Hello'])['ok'] === false, 'a blank title is refused');
check(TournamentAnnouncement::fromInput(['title' => 'Hi', 'body' => str_repeat('a', 501)])['ok'] === false, 'a long message is refused');

check(TournamentAnnouncement::hears('confirmed') === true, 'a confirmed captain hears the announcement');
check(TournamentAnnouncement::hears('pending') === true, 'a pending captain hears the announcement');
check(TournamentAnnouncement::hears('waitlisted') === true, 'a waitlisted captain hears the announcement');
check(TournamentAnnouncement::hears('cancelled') === false, 'a cancelled entry stays quiet');

check(TournamentAnnouncement::noticeTitle('City Open', 'Gates') === 'City Open: Gates', 'the notice names the event');

if ($failed > 0) {
    fwrite(STDERR, "$failed failed\n");
    exit(1);
}
echo "all passed\n";
