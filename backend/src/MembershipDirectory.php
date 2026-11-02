<?php

/** Owner view of peak-hour members. Phone numbers stay off this list. */
final class MembershipDirectory
{
    /** @param array<string,mixed> $row */
    public static function row(array $row): array
    {
        return [
            'id' => (int)($row['id'] ?? 0),
            'user_id' => (int)($row['user_id'] ?? 0),
            'user_name' => (string)($row['user_name'] ?? ''),
            'plan_name' => (string)($row['plan_name'] ?? ''),
            'slot_type' => (string)($row['slot_type'] ?? ''),
            'status' => (string)($row['status'] ?? ''),
            'start_date' => $row['start_date'] ?? null,
            'end_date' => $row['end_date'] ?? null,
        ];
    }
}
