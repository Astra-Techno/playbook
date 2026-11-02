<?php

require_once __DIR__ . '/../src/TournamentDraw.php';

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

$pair = TournamentDraw::pair([
    ['id' => 4, 'state' => 'confirmed'],
    ['id' => 9, 'state' => 'confirmed'],
]);
check($pair['ok'] === true, 'two confirmed entries can play');
check(TournamentDraw::pair([['id' => 4, 'state' => 'confirmed']])['ok'] === false, 'one entry cannot make a match');
check(TournamentDraw::pair([
    ['id' => 4, 'state' => 'confirmed'],
    ['id' => 4, 'state' => 'confirmed'],
])['ok'] === false, 'an entry cannot play itself');
check(TournamentDraw::pair([
    ['id' => 4, 'state' => 'pending'],
    ['id' => 9, 'state' => 'confirmed'],
])['ok'] === false, 'a pending entry stays out of the draw');

$scored = TournamentDraw::score(4, 9, 4, 2, 1, false);
check($scored['ok'] === true && $scored['status'] === 'completed', 'the higher score wins');
check(TournamentDraw::score(4, 9, 9, 2, 1, false)['ok'] === false, 'the lower score cannot be the winner');
check(TournamentDraw::score(4, 9, 4, 1, 1, false)['ok'] === false, 'a tied score has no winner');
check(TournamentDraw::score(4, 9, 4, -1, 0, false)['ok'] === false, 'a negative score is refused');
check(TournamentDraw::score(4, 9, 4, 2, 0, true)['ok'] === false, 'a second result is refused');

$drawn = TournamentDraw::bracket([
    ['id' => 9, 'state' => 'confirmed'],
    ['id' => 2, 'state' => 'pending'],
    ['id' => 4, 'state' => 'confirmed'],
    ['id' => 7, 'state' => 'confirmed'],
], false);
check(
    $drawn['ok'] === true
        && $drawn['pairs'] === [['home' => 4, 'away' => 7]]
        && $drawn['bye'] === 9,
    'confirmed entries pair in id order and the last one has a bye'
);
check(TournamentDraw::bracket([
    ['id' => 4, 'state' => 'confirmed'],
    ['id' => 9, 'state' => 'waitlisted'],
], false)['ok'] === false, 'a bracket needs at least two confirmed entries');
check(TournamentDraw::bracket([
    ['id' => 4, 'state' => 'confirmed'],
    ['id' => 9, 'state' => 'confirmed'],
], true)['ok'] === false, 'a second bracket is refused');
check(TournamentDraw::bracket([
    ['id' => 4, 'state' => 'confirmed'],
    ['id' => 4, 'state' => 'confirmed'],
], false)['ok'] === false, 'the same entry cannot be drawn twice');

check(TournamentDraw::advance([
    ['round' => 'Round 1', 'status' => 'completed', 'home' => 4, 'winner' => 4],
    ['round' => 'Round 1', 'status' => 'scheduled', 'home' => 7, 'winner' => 0],
])['ok'] === false, 'the next round waits until this round is scored');
$moved = TournamentDraw::advance([
    ['round' => 'Round 1', 'status' => 'completed', 'home' => 4, 'winner' => 4],
    ['round' => 'Round 1', 'status' => 'bye', 'home' => 9, 'winner' => 0],
    ['round' => 'Match', 'status' => 'scheduled', 'home' => 1, 'winner' => 0],
]);
check(
    $moved['ok'] === true
        && $moved['round'] === 'Round 2'
        && $moved['pairs'] === [['home' => 4, 'away' => 9]]
        && $moved['bye'] === null
        && $moved['champion'] === null,
    'a winner and a bye make the next round'
);
$champion = TournamentDraw::advance([
    ['round' => 'Round 1', 'status' => 'completed', 'home' => 4, 'winner' => 4],
    ['round' => 'Round 2', 'status' => 'completed', 'home' => 4, 'winner' => 4],
]);
check($champion['ok'] === true && $champion['champion'] === 4 && $champion['pairs'] === [], 'the last winner is the champion');
check(TournamentDraw::advance([
    ['round' => 'Round 1', 'status' => 'completed', 'home' => 4, 'winner' => 4],
    ['round' => 'Round 1', 'status' => 'bye', 'home' => 4, 'winner' => 0],
])['ok'] === false, 'a player can advance only once');
check(TournamentDraw::advance([
    ['round' => 'Match', 'status' => 'completed', 'home' => 4, 'winner' => 4],
])['ok'] === false, 'a manual match does not start the next round');

if ($failed > 0) {
    fwrite(STDERR, "$failed failed\n");
    exit(1);
}
echo "all passed\n";
