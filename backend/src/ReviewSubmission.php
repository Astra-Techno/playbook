<?php

/**
 * Reads a venue review body. A booking id is optional: the venue page
 * can submit a rating without one.
 */
class ReviewSubmission
{
    public static function fromBody($raw): array
    {
        if (is_object($raw)) {
            $raw = (array)$raw;
        }
        if (!is_array($raw)) {
            $raw = [];
        }

        $courtId = (int)($raw['court_id'] ?? $raw['courtId'] ?? 0);
        $rating = (int)($raw['rating'] ?? 0);
        $bookingId = (int)($raw['booking_id'] ?? $raw['bookingId'] ?? 0);
        $comment = trim(strip_tags((string)($raw['comment'] ?? '')));
        if (strlen($comment) > 1000) {
            $comment = substr($comment, 0, 1000);
        }
        $comment = htmlspecialchars($comment, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');

        return [
            'court_id' => $courtId,
            'rating' => $rating,
            'booking_id' => $bookingId > 0 ? $bookingId : null,
            'comment' => $comment,
            'ok' => $courtId > 0 && $rating >= 1 && $rating <= 5,
        ];
    }

    /** My Reviews has no court. A venue list still needs a court id. */
    public static function listScope(int $courtId, int $ownerId, bool $signedIn): string
    {
        if ($ownerId > 0 && $courtId < 1) {
            return 'owner';
        }
        if ($courtId > 0) {
            return 'court';
        }
        if ($signedIn) {
            return 'mine';
        }
        return 'court_required';
    }
}
