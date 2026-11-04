<?php

require_once __DIR__ . '/../src/CommerceSettings.php';

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

function rejected(callable $fn): bool
{
    try {
        $fn();
        return false;
    } catch (InvalidArgumentException $e) {
        return true;
    }
}

$defaults = CommerceSettings::defaults();
check($defaults['checkout.enabled'] === true, 'online checkout starts enabled');
check($defaults['fee.enabled'] === false, 'a platform fee starts off');
check($defaults['cancellation.full_hours'] === 12, 'a full refund needs 12 hours notice');

$policy = CommerceSettings::normalize(['fee.enabled' => true, 'fee.amount' => 10]);
check($policy['fee.enabled'] === true && $policy['fee.amount'] === 10.0, 'a fixed fee is kept');
check(rejected(fn() => CommerceSettings::normalize(['not.a.setting' => 1])), 'an unknown setting is rejected');
check(rejected(fn() => CommerceSettings::normalize(['company.gst_registered' => true])), 'a GSTIN is required when registration is on');
check(rejected(fn() => CommerceSettings::normalize(['fee.mode' => 'percentage', 'fee.amount' => 101])), 'a percentage fee cannot exceed 100');
check(rejected(fn() => CommerceSettings::normalize(['cancellation.partial_hours' => 20])), 'partial notice cannot pass the full-refund notice');
check(rejected(fn() => CommerceSettings::normalize(['cancellation.late_percent' => 80])), 'a late refund cannot exceed the partial refund');

$plain = CommerceSettings::price(10000, $defaults);
check($plain['venue']['total'] === 10000 && $plain['fee']['total'] === 0 && $plain['total'] === 10000, 'a price with no fee stays the venue total');
$withFee = CommerceSettings::price(10000, $policy);
check($withFee['fee']['total'] === 1000 && $withFee['total'] === 11000, 'a fixed fee of 10 rupees is 1000 paise');

$inclusive = CommerceSettings::tax(11800, 18, true);
check($inclusive['base'] === 10000 && $inclusive['tax'] === 1800 && $inclusive['total'] === 11800, 'inclusive GST splits the base and the tax');

$cost = CommerceSettings::estimateCost(10000, $defaults);
check($cost['estimate_only'] === true && $cost['total'] === $cost['gateway'] + $cost['split'] + $cost['tax'], 'a processing estimate is labelled and adds up');

$db = new PDO('sqlite::memory:');
$db->exec('CREATE TABLE config (`key` TEXT PRIMARY KEY, `value` TEXT)');
$db->prepare('INSERT INTO config (`key`, `value`) VALUES (?, ?)')->execute([
    CommerceSettings::KEY,
    json_encode(['checkout.enabled' => false]),
]);
$loaded = CommerceSettings::load($db, 4);
check($loaded['checkout.enabled'] === false, 'a stored policy replaces the default');
check($loaded['fee.enabled'] === false, 'a stored policy keeps the other defaults');

if ($failed > 0) {
    fwrite(STDERR, "$failed failed\n");
    exit(1);
}
echo "all passed\n";
