<?php

require_once __DIR__ . '/../src/SlotLock.php';

function check(bool $condition, string $message): void
{
    static $failed = 0;
    if ($condition) {
        echo "ok  $message\n";
        return;
    }
    $failed++;
    fwrite(STDERR, "FAIL $message\n");
    $GLOBALS['slot_lock_failed'] = $failed;
}

check(SlotLock::name(4) === 'kocourt-court-4', 'a venue uses one lock name');
check(strlen(SlotLock::name(4)) <= 64, 'the lock name fits MySQL');

if (!empty($GLOBALS['slot_lock_failed'])) {
    fwrite(STDERR, $GLOBALS['slot_lock_failed'] . " failed\n");
    exit(1);
}
echo "all passed\n";
