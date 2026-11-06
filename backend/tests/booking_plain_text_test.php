<?php

require_once __DIR__ . '/../src/Models/Booking.php';

function expect_text($label, $condition) {
    if (!$condition) {
        fwrite(STDERR, "FAIL $label\n");
        exit(1);
    }
    echo "PASS $label\n";
}

expect_text('a rupee amount stays a price', bookingPlainText(1500.5) === '1500.5');
expect_text('a clock time stays a clock time', bookingPlainText('2026-11-07 18:00:00') === '2026-11-07 18:00:00');

echo "booking text ok\n";
