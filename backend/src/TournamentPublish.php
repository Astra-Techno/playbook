<?php

/** Publish a draft. A venue with start and end closes through one venue-wide block. */
final class TournamentPublish
{
    /** @return array{ok:bool,message?:string,block?:bool} */
    public static function plan(string $status, ?int $courtId, ?string $start, ?string $end, bool $slotFree): array
    {
        if ($status !== 'draft') {
            return ['ok' => false, 'message' => 'Only a draft event can be published.'];
        }
        $hasCourt = $courtId !== null && $courtId > 0;
        $hasStart = $start !== null && $start !== '';
        $hasEnd = $end !== null && $end !== '';
        if ($hasCourt && (!$hasStart || !$hasEnd)) {
            return ['ok' => false, 'message' => 'Add a start and end before publishing an event at a venue.'];
        }
        if ($hasStart !== $hasEnd) {
            return ['ok' => false, 'message' => 'Start and end must both be set.'];
        }
        if ($hasStart && $end <= $start) {
            return ['ok' => false, 'message' => 'The end must be after the start.'];
        }
        $block = $hasCourt && $hasStart && $hasEnd;
        if ($block && !$slotFree) {
            return ['ok' => false, 'message' => 'That venue already has a booking or a closure in these times.'];
        }
        return ['ok' => true, 'block' => $block];
    }

    /** @return array{ok:bool,message?:string} */
    public static function unpublish(string $status): array
    {
        if ($status !== 'published') {
            return ['ok' => false, 'message' => 'Only a published event can be unpublished.'];
        }
        return ['ok' => true];
    }
}
