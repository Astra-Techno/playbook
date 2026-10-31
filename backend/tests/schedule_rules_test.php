<?php

require_once __DIR__ . '/../src/ScheduleRules.php';

$failed = 0;

function check(bool $condition, string $message): void
{
    global $failed;
    if ($condition) {
        echo "ok  $message\n";
        return;
    }
    $failed++;
    fwrite(STDERR, "FAIL $message\n");
}

$venuePeak = ['id' => 2, 'priority' => 10, 'day_type' => 'weekend', 'start_hour' => 18, 'end_hour' => 22, 'price' => 900, 'valid_from' => null, 'valid_to' => null];
$venueDay = ['id' => 1, 'priority' => 1, 'day_type' => 'all', 'start_hour' => 0, 'end_hour' => 24, 'price' => 400, 'valid_from' => null, 'valid_to' => null];
$facilityPeak = ['id' => 3, 'sub_court_id' => 8, 'priority' => 0, 'day_type' => 'weekend', 'start_hour' => 18, 'end_hour' => 22, 'price' => 1200, 'valid_from' => null, 'valid_to' => null];

check(ScheduleRules::dayType('2026-10-31') === 'weekend', 'Saturday is weekend');
check(ScheduleRules::dayType('2026-10-30') === 'weekday', 'Friday is weekday');
check(ScheduleRules::baseRate(400, null) === 400.0, 'missing facility rate uses the venue rate');
check(ScheduleRules::baseRate(400, 0) === 400.0, 'zero facility rate uses the venue rate');
check(ScheduleRules::baseRate(400, 650) === 650.0, 'facility rate replaces the venue rate');

$split = ScheduleRules::splitRules([$venuePeak, $venueDay, $facilityPeak], 8);
$saturdayEvening = ScheduleRules::hourlyRate($split['facility'], $split['venue'], 400, 19, 'weekend', '2026-10-31');
check($saturdayEvening['effective_price'] === 1200.0, 'facility rule beats a higher-priority venue rule');
check((int)$saturdayEvening['rule']['id'] === 3, 'the facility rule is the one quoted');

$fridayEvening = ScheduleRules::hourlyRate($split['facility'], $split['venue'], 400, 19, 'weekday', '2026-10-30');
check($fridayEvening['effective_price'] === 400.0, 'weekday evening falls through to the all-day venue rule');

$samePriority = ScheduleRules::pickRule([
    ['id' => 4, 'priority' => 5, 'day_type' => 'all', 'start_hour' => 0, 'end_hour' => 24, 'price' => 100, 'valid_from' => null, 'valid_to' => null],
    ['id' => 9, 'priority' => 5, 'day_type' => 'all', 'start_hour' => 0, 'end_hour' => 24, 'price' => 150, 'valid_from' => null, 'valid_to' => null],
], 10, 'weekday', '2026-10-30');
check($samePriority !== null && (int)$samePriority['id'] === 9, 'equal priority keeps the newer rule');

$dated = ['id' => 6, 'priority' => 3, 'day_type' => 'all', 'start_hour' => 0, 'end_hour' => 24, 'price' => 700, 'valid_from' => '2026-10-01', 'valid_to' => '2026-10-31'];
check(ScheduleRules::ruleMatches($dated, 10, 'weekday', '2026-10-31'), 'valid_to is inclusive');
check(!ScheduleRules::ruleMatches($dated, 10, 'weekday', '2026-11-01'), 'the day after valid_to does not match');

$quote = ScheduleRules::quote(
    '2026-10-31 18:00:00',
    '2026-10-31 19:00:00',
    400,
    $split['facility'],
    $split['venue']
);
check($quote === 1200.0, 'one hour is two half-hour steps at the peak rate');

$mixed = ScheduleRules::quote(
    '2026-10-31 17:30:00',
    '2026-10-31 18:30:00',
    400,
    $split['facility'],
    $split['venue']
);
check($mixed === 800.0, 'a slot crossing the peak boundary uses each hour rate');

check(ScheduleRules::capacityAllows('exclusive', 0, 4), 'exclusive slot with no confirmed row is open');
check(!ScheduleRules::capacityAllows('exclusive', 1, 4), 'one confirmed row closes an exclusive slot');
check(ScheduleRules::capacityAllows('shared', 2, 3), 'shared slot stays open below capacity');
check(!ScheduleRules::capacityAllows('shared', 3, 3), 'shared slot closes when the row count reaches capacity');
check(!ScheduleRules::capacityAllows('shared', 1, 0), 'a missing capacity still allows one shared row only');

check(ScheduleRules::blockAppliesToRequest(null, 8), 'a venue block covers a facility');
check(ScheduleRules::blockAppliesToRequest(null, null), 'a venue block covers a venue-level check');
check(ScheduleRules::blockAppliesToRequest(8, 8), 'a facility block covers that facility');
check(!ScheduleRules::blockAppliesToRequest(8, 9), 'a facility block does not cover another facility');
check(!ScheduleRules::blockAppliesToRequest(8, null), 'a facility block does not cover a venue-level check');

check(ScheduleRules::intervalsOverlap(
    '2026-10-31 22:00:00',
    '2026-11-01 02:00:00',
    '2026-11-01 01:00:00',
    '2026-11-01 02:00:00'
), 'an overnight closure covers the next morning');
check(!ScheduleRules::intervalsOverlap(
    '2026-10-31 22:00:00',
    '2026-11-01 02:00:00',
    '2026-11-01 02:00:00',
    '2026-11-01 03:00:00'
), 'a closure ends at the next slot start');

check(ScheduleRules::annualTemplateHits(
    '2026-10-31 18:00:00',
    '2026-10-31 19:00:00',
    '2020-10-31 18:00:00',
    '2020-10-31 20:00:00'
), 'an annual template hits the same month and day');
check(ScheduleRules::annualTemplateHits(
    '2026-10-31 23:00:00',
    '2026-10-31 23:30:00',
    '2020-10-31 22:00:00',
    '2020-11-01 02:00:00'
), 'an annual template that passes midnight covers that evening');
check(!ScheduleRules::annualTemplateHits(
    '2026-11-01 01:00:00',
    '2026-11-01 02:00:00',
    '2020-10-31 22:00:00',
    '2020-11-01 02:00:00'
), 'a next-morning booking does not use the previous day annual template');

check(ScheduleRules::windowInsideHours('06:00:00', '22:00:00', '2026-10-31 07:00:00', '2026-10-31 08:00:00'), 'a slot inside venue hours is open');
check(!ScheduleRules::windowInsideHours('06:00:00', '22:00:00', '2026-10-31 21:00:00', '2026-10-31 23:00:00'), 'a slot past closing is outside venue hours');
check(!ScheduleRules::windowInsideHours('06:00:00', '22:00:00', '2026-10-31 23:00:00', '2026-11-01 01:00:00'), 'ordinary hours do not cross midnight');
check(ScheduleRules::windowInsideHours('18:00:00', '02:00:00', '2026-10-31 19:00:00', '2026-10-31 21:00:00'), 'overnight hours include the evening');
check(ScheduleRules::windowInsideHours('18:00:00', '02:00:00', '2026-10-31 23:00:00', '2026-11-01 01:00:00'), 'overnight hours include a window that crosses midnight');
check(ScheduleRules::windowInsideHours('18:00:00', '02:00:00', '2026-11-01 00:30:00', '2026-11-01 01:30:00'), 'overnight hours include the next morning');
check(!ScheduleRules::windowInsideHours('18:00:00', '02:00:00', '2026-11-01 03:00:00', '2026-11-01 04:00:00'), 'the closed gap of an overnight venue stays closed');

$applied = ScheduleRules::appliesWindow('2020-10-31 18:00:00', '2020-10-31 20:00:00', true, '2026-10-31');
check($applied === ['2026-10-31 18:00:00', '2026-10-31 20:00:00'], 'an annual block is shown on the requested date');

if ($failed > 0) {
    fwrite(STDERR, "$failed failed\n");
    exit(1);
}
echo "all passed\n";
