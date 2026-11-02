<?php

/** Organizer CSV of entry rows. Names only. No phone and no idempotency key. */
final class TournamentParticipantExport
{
    public const HEADER = 'Category,Player,State,Fee,Code,"Checked in"';

    /** @param list<array{category:string,player:string,state:string,fee:mixed,checked_in_at?:mixed}> $rows */
    public static function csv(array $rows): string
    {
        $handle = fopen('php://temp', 'r+');
        fputcsv($handle, ['Category', 'Player', 'State', 'Fee', 'Code', 'Checked in']);
        foreach ($rows as $row) {
            fputcsv($handle, [
                (string)($row['category'] ?? ''),
                (string)($row['player'] ?? ''),
                (string)($row['state'] ?? ''),
                (string)($row['fee'] ?? ''),
                (string)($row['code'] ?? ''),
                (string)($row['checked_in_at'] ?? ''),
            ]);
        }
        rewind($handle);
        $csv = stream_get_contents($handle);
        fclose($handle);
        return $csv === false ? '' : $csv;
    }
}
