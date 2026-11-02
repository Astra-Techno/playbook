<?php

/** Draft event row for `tournaments` plus the creator's organizer row. */
final class TournamentDraft
{
    public const TABLES = [
        'tournaments',
        'tournament_organizers',
        'tournament_categories',
        'tournament_registrations',
        'tournament_registration_members',
        'tournament_capacity_holds',
    ];

    /** @return array{ok:bool,message?:string,tournament?:array,organizer?:array} */
    public static function fromInput(array $input, int $userId): array
    {
        $title = trim((string)($input['title'] ?? ''));
        $sport = trim((string)($input['sport'] ?? ''));
        if ($userId <= 0 || $title === '' || $sport === '') {
            return ['ok' => false, 'message' => 'A title and a sport are required.'];
        }
        if (strlen($title) > 160 || strlen($sport) > 60) {
            return ['ok' => false, 'message' => 'The title or sport is too long.'];
        }
        $visibility = (string)($input['visibility'] ?? 'private');
        if (!in_array($visibility, ['private', 'public'], true)) {
            return ['ok' => false, 'message' => 'visibility must be private or public.'];
        }
        $courtId = $input['court_id'] ?? null;
        if ($courtId === '' || $courtId === null) {
            $courtId = null;
        } elseif (!is_numeric($courtId) || (int)$courtId <= 0) {
            return ['ok' => false, 'message' => 'court_id must be a venue id.'];
        } else {
            $courtId = (int)$courtId;
        }

        $start = self::clock($input['start_time'] ?? null);
        $end = self::clock($input['end_time'] ?? null);
        $deadline = self::clock($input['registration_deadline'] ?? null);
        if ($start === false || $end === false || $deadline === false) {
            return ['ok' => false, 'message' => 'Times must be YYYY-MM-DD HH:MM:SS.'];
        }
        $sponsor = trim((string)($input['sponsor_name'] ?? ''));
        if (strlen($sponsor) > 120) {
            return ['ok' => false, 'message' => 'The sponsor name is too long.'];
        }

        return [
            'ok' => true,
            'tournament' => [
                'title' => $title,
                'sport' => $sport,
                'court_id' => $courtId,
                'start_time' => $start,
                'end_time' => $end,
                'timezone' => 'Asia/Kolkata',
                'status' => 'draft',
                'visibility' => $visibility,
                'source_type' => 'internal',
                'registration_deadline' => $deadline,
                'sponsor_name' => $sponsor === '' ? null : $sponsor,
                'created_by' => $userId,
            ],
            'organizer' => [
                'user_id' => $userId,
                'role' => 'organizer',
            ],
        ];
    }

    /** @return string|null|false */
    private static function clock(mixed $value): string|null|false
    {
        if ($value === null || $value === '') {
            return null;
        }
        $value = trim((string)$value);
        if (!preg_match('/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$/', $value)) {
            return false;
        }
        return $value;
    }
}
