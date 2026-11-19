<?php

require_once __DIR__ . '/../src/AccountLookup.php';

function expect_lookup($label, $condition) {
    if (!$condition) {
        fwrite(STDERR, "FAIL $label\n");
        exit(1);
    }
    echo "PASS $label\n";
}

expect_lookup('spaces normalize to 10 digits', AccountLookup::normalize('98765 43210') === '9876543210');
expect_lookup('+91 normalizes to 10 digits', AccountLookup::normalize('+91 98765 43210') === '9876543210');
expect_lookup('91 prefix normalizes to 10 digits', AccountLookup::normalize('919876543210') === '9876543210');
expect_lookup('a leading 0 normalizes to 10 digits', AccountLookup::normalize('09876543210') === '9876543210');
expect_lookup('a short number is rejected', AccountLookup::normalize('98765') === '');
expect_lookup('a blank phone matches nobody', AccountLookup::keys('  ') === []);

$keys = AccountLookup::keys('+91 98765 43210');
expect_lookup('keys include the 10-digit mobile', in_array('9876543210', $keys, true));
expect_lookup('keys include +91 without spaces', in_array('+919876543210', $keys, true));
expect_lookup('keys include 91 without plus', in_array('919876543210', $keys, true));

echo "account lookup ok\n";
