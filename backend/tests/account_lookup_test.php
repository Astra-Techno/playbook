<?php

require_once __DIR__ . '/../src/AccountLookup.php';

function expect_lookup($label, $condition) {
    if (!$condition) {
        fwrite(STDERR, "FAIL $label\n");
        exit(1);
    }
    echo "PASS $label\n";
}

$keys = AccountLookup::keys('98765 43210');
expect_lookup('a spaced mobile keeps the last 10 digits', $keys[3] === '9876543210');
expect_lookup('a country code is searched too', $keys[2] === '+919876543210');
expect_lookup('a blank phone matches nobody', AccountLookup::keys('  ') === []);

echo "account lookup ok\n";
