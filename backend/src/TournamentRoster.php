<?php

/** Partners named on a doubles or team entry. The captain is stored separately. */
final class TournamentRoster
{
    /** @return array{ok:bool,message?:string,members?:list<array{user_id:?int,display_name:string}>} */
    public static function extras(string $format, mixed $input, int $captainUserId): array
    {
        if ($input === null || $input === '') {
            $input = [];
        }
        if (!is_array($input) || !array_is_list($input)) {
            return ['ok' => false, 'message' => 'members must be a list.'];
        }
        $members = [];
        foreach ($input as $row) {
            if (!is_array($row)) {
                return ['ok' => false, 'message' => 'Each partner needs a name or a player id.'];
            }
            $name = trim((string)($row['display_name'] ?? ''));
            $userId = $row['user_id'] ?? null;
            if ($userId === '' || $userId === null) {
                $userId = null;
            } elseif (!is_numeric($userId) || (int)$userId <= 0) {
                return ['ok' => false, 'message' => 'A partner player id must be a user id.'];
            } else {
                $userId = (int)$userId;
            }
            if ($userId !== null && $userId === $captainUserId) {
                return ['ok' => false, 'message' => 'The captain is already on the entry.'];
            }
            if ($name === '' && $userId === null) {
                return ['ok' => false, 'message' => 'Each partner needs a name or a player id.'];
            }
            if (strlen($name) > 120) {
                return ['ok' => false, 'message' => 'A partner name is too long.'];
            }
            if ($name === '') {
                $name = 'Player ' . $userId;
            }
            $members[] = ['user_id' => $userId, 'display_name' => $name];
        }
        $count = count($members);
        if ($format === 'singles') {
            if ($count !== 0) {
                return ['ok' => false, 'message' => 'Singles is the captain only.'];
            }
            return ['ok' => true, 'members' => []];
        }
        if ($format === 'doubles') {
            if ($count !== 1) {
                return ['ok' => false, 'message' => 'Doubles needs one partner.'];
            }
            return ['ok' => true, 'members' => $members];
        }
        if ($format === 'team') {
            if ($count < 1 || $count > 12) {
                return ['ok' => false, 'message' => 'A team needs 1 to 12 partners besides the captain.'];
            }
            return ['ok' => true, 'members' => $members];
        }
        return ['ok' => false, 'message' => 'This category cannot take entries.'];
    }
}
