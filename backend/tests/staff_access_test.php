<?php

require_once __DIR__ . '/../src/StaffAccess.php';

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

check(StaffAccess::role('manager') === 'manager', 'manager is a staff role');
check(StaffAccess::role('viewer') === 'viewer', 'viewer is a staff role');
check(StaffAccess::role('staff') === null, 'a free-text role is refused');
check(StaffAccess::role('') === null, 'a blank role is refused');

check(StaffAccess::allows('manager', 'walk_in', true) === true, 'a manager can record a walk-in at their venue');
check(StaffAccess::allows('manager', 'attendance', true) === true, 'a manager can mark attendance at their venue');
check(StaffAccess::allows('manager', 'blocks', true) === true, 'a manager can close a slot at their venue');
check(StaffAccess::allows('manager', 'customers', true) === true, 'a manager can open the customer directory at their venue');
check(StaffAccess::allows('viewer', 'calendar', true) === true, 'a viewer can open the calendar at their venue');
check(StaffAccess::allows('viewer', 'bookings', true) === true, 'a viewer can read bookings at their venue');
check(StaffAccess::allows('viewer', 'walk_in', true) === false, 'a viewer cannot record a walk-in');
check(StaffAccess::allows('viewer', 'customers', true) === false, 'a viewer cannot open the customer directory');
check(StaffAccess::allows('manager', 'staff', true) === false, 'a manager cannot invite staff');
check(StaffAccess::allows('manager', 'earnings', true) === false, 'a manager cannot open earnings');
check(StaffAccess::allows('manager', 'walk_in', false) === false, 'a manager of one venue cannot act at another venue');
check(StaffAccess::allows('viewer', 'calendar', false) === false, 'a viewer of one venue cannot read another venue');

if ($failed > 0) {
    fwrite(STDERR, "$failed failed\n");
    exit(1);
}
echo "all passed\n";
