<?php

require_once __DIR__ . '/../src/TournamentCategory.php';

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

$row = TournamentCategory::fromInput([
    'name' => ' Open singles ',
    'format' => 'singles',
    'eligibility' => 'Under 17',
    'fee' => '250.5',
    'capacity' => 32,
    'waitlist' => true,
], 9);
check($row['ok'] === true, 'an entry class can be described');
check($row['category']['name'] === 'Open singles' && $row['category']['format'] === 'singles', 'the name and format are kept');
check($row['category']['fee'] === 250.5 && $row['category']['capacity'] === 32 && $row['category']['waitlist'] === 1, 'fee, capacity, and waitlist are stored');
check($row['category']['tournament_id'] === 9, 'the class belongs to the event');

$plain = TournamentCategory::fromInput(['name' => 'Doubles'], 3);
check($plain['category']['format'] === 'singles' && $plain['category']['capacity'] === 0 && $plain['category']['fee'] === 0.0 && $plain['category']['approval'] === 0, 'a class defaults to singles with no fee, no seat limit, and no approval');

check(TournamentCategory::fromInput(['name' => ''], 3)['ok'] === false, 'a name is required');
check(TournamentCategory::fromInput(['name' => 'Open', 'format' => 'mixed'], 3)['ok'] === false, 'an unknown format is rejected');
check(TournamentCategory::fromInput(['name' => 'Open', 'fee' => -1], 3)['ok'] === false, 'a negative fee is rejected');
check(TournamentCategory::fromInput(['name' => 'Open', 'capacity' => 1.5], 3)['ok'] === false, 'a fractional capacity is rejected');

if ($failed > 0) {
    fwrite(STDERR, "$failed failed\n");
    exit(1);
}
echo "all passed\n";
