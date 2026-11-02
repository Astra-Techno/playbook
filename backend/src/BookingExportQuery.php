<?php

/**
 * Query values for GET /earnings/export.
 * A day is YYYY-MM-DD. An omitted day stays open. An invalid day is rejected.
 */
class BookingExportQuery
{
    /** @return string|null|false */
    public static function day(mixed $value): string|null|false
    {
        if ($value === null || $value === '') {
            return null;
        }
        $value = trim((string)$value);
        if (!preg_match('/^\d{4}-\d{2}-\d{2}$/', $value)) {
            return false;
        }
        $parsed = DateTime::createFromFormat('!Y-m-d', $value);
        if (!$parsed || $parsed->format('Y-m-d') !== $value) {
            return false;
        }
        return $value;
    }
}
