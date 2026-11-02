<?php

require_once __DIR__ . '/../src/BookingExportQuery.php';

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

check(BookingExportQuery::day(null) === null, 'an omitted day stays open');
check(BookingExportQuery::day('') === null, 'a blank day stays open');
check(BookingExportQuery::day('2026-11-02') === '2026-11-02', 'a calendar day is kept');
check(BookingExportQuery::day('2026-02-31') === false, 'an impossible day is rejected');
check(BookingExportQuery::day('02-11-2026') === false, 'a non ISO day is rejected');

if ($failed > 0) {
    fwrite(STDERR, "$failed failed\n");
    exit(1);
}
echo "all passed\n";
