<?php

/**
 * Peak window classification and per-space overrides for members-only rules.
 * Peak time bands always come from the parent court row.
 */
class PeakAccess
{
    /** @return 'morning'|'evening'|null */
    public static function getPeakType(string $startDatetime, array $court): ?string
    {
        $time = date('H:i:s', strtotime($startDatetime));
        $mps = $court['morning_peak_start'] ?? '05:00:00';
        $mpe = $court['morning_peak_end']   ?? '09:00:00';
        $eps = $court['evening_peak_start'] ?? '17:00:00';
        $epe = $court['evening_peak_end']   ?? '21:00:00';

        if ($time >= $mps && $time < $mpe) {
            return 'morning';
        }
        if ($time >= $eps && $time < $epe) {
            return 'evening';
        }
        return null;
    }

    /**
     * Whether subscription is required during peak for this court + optional sub-court.
     * subCourt row may include peak_members_override: NULL = inherit venue, 0 = open at peak, 1 = members at peak.
     *
     * @param array       $court   courts.* row
     * @param array|null  $subCourt sub_courts row or null (whole venue / no space)
     */
    public static function peakMembersOnlyApplies(array $court, ?array $subCourt): bool
    {
        $courtOn = !empty($court['peak_members_only']);
        if ($subCourt === null) {
            return $courtOn;
        }
        if (!array_key_exists('peak_members_override', $subCourt) || $subCourt['peak_members_override'] === null || $subCourt['peak_members_override'] === '') {
            return $courtOn;
        }
        return (int)$subCourt['peak_members_override'] === 1;
    }
}
