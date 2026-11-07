<?php

require_once __DIR__ . '/../src/MatchRoster.php';

function expect_match($label, $condition) {
    if (!$condition) {
        fwrite(STDERR, "FAIL $label\n");
        exit(1);
    }
    echo "PASS $label\n";
}

expect_match('one needed player leaves a seat after the host joins', MatchRoster::spotsLeft(1, 1) === 1);
expect_match('that seat is not full', MatchRoster::isFull(1, 1) === false);
expect_match('the seat closes after the other player joins', MatchRoster::isFull(1, 2) === true);
expect_match('two needed players stay open for the first joiner', MatchRoster::spotsLeft(2, 1) === 2);
expect_match('a zero request still keeps one seat', MatchRoster::spotsLeft(0, 1) === 1);

echo "match roster ok\n";
