<?php

/** One entry class on a draft event. Capacity 0 means the class has no seat limit yet. */
final class TournamentCategory
{
    /** @return array{ok:bool,message?:string,category?:array} */
    public static function fromInput(array $input, int $tournamentId): array
    {
        $name = trim((string)($input['name'] ?? ''));
        if ($tournamentId <= 0 || $name === '') {
            return ['ok' => false, 'message' => 'A category name is required.'];
        }
        if (strlen($name) > 120) {
            return ['ok' => false, 'message' => 'The category name is too long.'];
        }
        $format = (string)($input['format'] ?? 'singles');
        if (!in_array($format, ['singles', 'doubles', 'team'], true)) {
            return ['ok' => false, 'message' => 'format must be singles, doubles, or team.'];
        }
        $eligibility = trim((string)($input['eligibility'] ?? ''));
        if (strlen($eligibility) > 255) {
            return ['ok' => false, 'message' => 'Eligibility is too long.'];
        }
        $fee = self::money($input['fee'] ?? null);
        if ($fee === false) {
            return ['ok' => false, 'message' => 'fee must be zero or more.'];
        }
        $capacity = self::whole($input['capacity'] ?? null);
        if ($capacity === false) {
            return ['ok' => false, 'message' => 'capacity must be a whole number, zero or more.'];
        }
        $wait = self::flag($input['waitlist'] ?? false);
        if ($wait === false) {
            return ['ok' => false, 'message' => 'waitlist must be true or false.'];
        }
        $approval = self::flag($input['approval'] ?? false);
        if ($approval === false) {
            return ['ok' => false, 'message' => 'approval must be true or false.'];
        }

        return [
            'ok' => true,
            'category' => [
                'tournament_id' => $tournamentId,
                'name' => $name,
                'format' => $format,
                'eligibility' => $eligibility === '' ? null : $eligibility,
                'fee' => $fee,
                'capacity' => $capacity,
                'waitlist' => $wait,
                'approval' => $approval,
            ],
        ];
    }

    /** @return float|false */
    private static function money(mixed $value): float|false
    {
        if ($value === null || $value === '') {
            return 0.0;
        }
        if (!is_numeric($value) || (float)$value < 0) {
            return false;
        }
        return round((float)$value, 2);
    }

    /** @return int|false */
    private static function whole(mixed $value): int|false
    {
        if ($value === null || $value === '') {
            return 0;
        }
        if (is_int($value)) {
            return $value >= 0 ? $value : false;
        }
        if (is_string($value) && preg_match('/^\d+$/', $value)) {
            return (int)$value;
        }
        return false;
    }

    /** @return int|false */
    private static function flag(mixed $value): int|false
    {
        if (!in_array($value, [false, true, 0, 1, '0', '1'], true)) {
            return false;
        }
        return ($value === true || $value === 1 || $value === '1') ? 1 : 0;
    }
}
