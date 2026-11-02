<?php

/** A message from an organizer to captains who still have an entry. */
final class TournamentAnnouncement
{
    /** @return array{ok:bool,message?:string,title?:string,body?:string} */
    public static function fromInput(array $input): array
    {
        $title = trim((string)($input['title'] ?? ''));
        $body = trim((string)($input['body'] ?? ''));
        if ($title === '' || $body === '') {
            return ['ok' => false, 'message' => 'A title and a message are required.'];
        }
        if (strlen($title) > 120 || strlen($body) > 500) {
            return ['ok' => false, 'message' => 'The title or message is too long.'];
        }
        return ['ok' => true, 'title' => $title, 'body' => $body];
    }

    public static function hears(string $state): bool
    {
        return in_array($state, ['confirmed', 'pending', 'waitlisted'], true);
    }

    public static function noticeTitle(string $eventTitle, string $title): string
    {
        $eventTitle = trim($eventTitle);
        $line = $eventTitle === '' ? $title : $eventTitle . ': ' . $title;
        if (function_exists('mb_substr')) {
            return mb_substr($line, 0, 255);
        }
        return substr($line, 0, 255);
    }
}
