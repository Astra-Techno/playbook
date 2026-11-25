<?php

/**
 * The public availability grid (GET /bookings?court_id=&date=, no sign-in)
 * only needs when a space is taken — never who booked it or what they paid.
 */
final class SlotPrivacy
{
    public const PUBLIC_FIELDS = ['sub_court_id', 'start_time', 'end_time', 'status'];

    /** @return array{sub_court_id:mixed,start_time:mixed,end_time:mixed,status:mixed} */
    public static function publicRow(array $row): array
    {
        $out = [];
        foreach (self::PUBLIC_FIELDS as $field) {
            $out[$field] = $row[$field] ?? null;
        }
        return $out;
    }
}
