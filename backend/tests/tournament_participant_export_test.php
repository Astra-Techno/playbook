<?php

require_once __DIR__ . '/../src/TournamentParticipantExport.php';

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

$empty = TournamentParticipantExport::csv([]);
check(str_starts_with($empty, TournamentParticipantExport::HEADER . "\n"), 'an event with no entries still has the header');

$csv = TournamentParticipantExport::csv([
    ['category' => 'Open, singles', 'player' => 'Ada', 'state' => 'confirmed', 'fee' => '100.00', 'code' => 'ABCD2345', 'checked_in_at' => '2026-12-01 09:00:00'],
]);
check(str_contains($csv, '"Open, singles"'), 'a comma in the category is quoted');
check(str_contains($csv, 'Ada,confirmed,100.00,ABCD2345,"2026-12-01 09:00:00"'), 'the row keeps the door code and the check-in time');

$absent = TournamentParticipantExport::csv([
    ['category' => 'Open', 'player' => 'Ada', 'state' => 'pending', 'fee' => '100.00', 'checked_in_at' => null],
]);
check(str_contains($absent, 'Ada,pending,100.00,'), 'an unchecked entry leaves the arrival blank');
check(!str_contains($csv, 'phone'), 'the file has no phone column');

if ($failed > 0) {
    fwrite(STDERR, "$failed failed\n");
    exit(1);
}
echo "all passed\n";
