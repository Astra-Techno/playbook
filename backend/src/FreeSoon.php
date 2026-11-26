<?php

/** "Free right now" on the player home: which of the next few full hours to probe. */
final class FreeSoon
{
    /**
     * @return list<array{0:string,1:string}> one-hour [start, end] windows from $from, same day only
     */
    public static function windows(string $from, int $hours): array
    {
        $ts = strtotime($from);
        if ($ts === false) return [];
        $ts = strtotime(date('Y-m-d H:00:00', $ts)); // snap to the local full hour (IST is +5:30)
        $day = date('Y-m-d', $ts);
        $out = [];
        for ($i = 0; $i < max(1, min(6, $hours)); $i++) {
            $start = $ts + $i * 3600;
            $end = $start + 3600;
            // A window ending exactly at midnight still belongs to today.
            if (date('Y-m-d', $start) !== $day || date('Y-m-d', $end - 1) !== $day) break;
            $out[] = [date('Y-m-d H:i:s', $start), date('Y-m-d H:i:s', $end)];
        }
        return $out;
    }

    /** @return list<int> up to 10 positive court ids from "3,5,x,5" */
    public static function ids(string $csv): array
    {
        $ids = array_values(array_unique(array_filter(array_map('intval', explode(',', $csv)), fn ($id) => $id > 0)));
        return array_slice($ids, 0, 10);
    }
}
