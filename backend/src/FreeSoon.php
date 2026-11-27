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

    public const STRIP_FIRST_HOUR = 6;   // strip covers 6 AM ..
    public const STRIP_HOURS = 17;       // .. up to the 10 PM slot (ends 11 PM)

    /**
     * The 17 one-hour windows of a venue's day strip, or [] for a bad date.
     * @return list<array{0:string,1:string}>
     */
    public static function dayWindows(string $date): array
    {
        if (!preg_match('/^\d{4}-\d{2}-\d{2}$/', $date) || strtotime($date) === false) return [];
        $out = [];
        for ($h = self::STRIP_FIRST_HOUR; $h < self::STRIP_FIRST_HOUR + self::STRIP_HOURS; $h++) {
            $out[] = [sprintf('%s %02d:00:00', $date, $h), sprintf('%s %02d:00:00', $date, $h + 1)];
        }
        return $out;
    }

    /** One strip letter: c closed, t taken, p free at peak, f free. */
    public static function stateChar(bool $open, bool $free, bool $peak): string
    {
        if (!$open) return 'c';
        if (!$free) return 't';
        return $peak ? 'p' : 'f';
    }

    /** @return list<int> up to 10 positive court ids from "3,5,x,5" */
    public static function ids(string $csv): array
    {
        $ids = array_values(array_unique(array_filter(array_map('intval', explode(',', $csv)), fn ($id) => $id > 0)));
        return array_slice($ids, 0, 10);
    }
}
