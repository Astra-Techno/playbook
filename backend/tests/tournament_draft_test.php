<?php

require_once __DIR__ . '/../src/TournamentDraft.php';

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

$draft = TournamentDraft::fromInput([
    'title' => ' City Open ',
    'sport' => 'Badminton',
    'visibility' => 'public',
    'start_time' => '2026-12-01 09:00:00',
], 12);
check($draft['ok'] === true, 'a signed-in user can draft an event');
check($draft['tournament']['status'] === 'draft', 'a new event stays a draft');
check($draft['tournament']['court_id'] === null, 'a venue is optional');
check($draft['tournament']['created_by'] === 12 && $draft['organizer']['role'] === 'organizer', 'the creator is the organizer without becoming a venue owner');
check($draft['tournament']['visibility'] === 'public' && $draft['tournament']['timezone'] === 'Asia/Kolkata', 'visibility and timezone are stored on the event');

$forced = TournamentDraft::fromInput(['title' => 'Open', 'sport' => 'Tennis', 'status' => 'published'], 4);
check($forced['tournament']['status'] === 'draft', 'the client cannot publish through the draft');

check(TournamentDraft::fromInput(['title' => '', 'sport' => 'Tennis'], 4)['ok'] === false, 'a title is required');
check(TournamentDraft::fromInput(['title' => 'Open', 'sport' => 'Tennis', 'visibility' => 'hidden'], 4)['ok'] === false, 'an unknown visibility is rejected');
check(TournamentDraft::fromInput(['title' => 'Open', 'sport' => 'Tennis', 'start_time' => 'tomorrow'], 4)['ok'] === false, 'a time must be a full datetime');

$sql = file_get_contents(__DIR__ . '/../migrations/022_tournaments.sql');
foreach (TournamentDraft::TABLES as $table) {
    check(str_contains($sql, 'CREATE TABLE IF NOT EXISTS ' . $table . ' ('), $table . ' is in the migration');
}
check(!str_contains($sql, 'event_registrations') && !str_contains($sql, 'tournament_matches'), 'draws and the partner event_* names are not in this migration');

if ($failed > 0) {
    fwrite(STDERR, "$failed failed\n");
    exit(1);
}
echo "all passed\n";
