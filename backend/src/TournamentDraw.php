<?php

/** A category match is two confirmed entries. The winner is the side with the higher score. */
final class TournamentDraw
{
    /** @param list<array<string,mixed>> $entries */
    public static function pair(array $entries): array
    {
        if (count($entries) !== 2) {
            return ['ok' => false, 'message' => 'A match needs two entries'];
        }
        $seen = [];
        foreach ($entries as $entry) {
            if (($entry['state'] ?? '') !== 'confirmed') {
                return ['ok' => false, 'message' => 'Both entries must be confirmed'];
            }
            $id = (int)($entry['id'] ?? 0);
            if ($id <= 0 || isset($seen[$id])) {
                return ['ok' => false, 'message' => 'A match needs two different entries'];
            }
            $seen[$id] = true;
        }
        return ['ok' => true];
    }

    /**
     * First round only. Entries are paired in id order. An odd entry is a bye.
     *
     * @param list<array<string,mixed>> $entries
     * @return array{ok:bool,message?:string,pairs?:list<array{home:int,away:int}>,bye?:int|null}
     */
    public static function bracket(array $entries, bool $alreadyDrawn): array
    {
        if ($alreadyDrawn) {
            return ['ok' => false, 'message' => 'This category already has a bracket'];
        }
        $ids = [];
        foreach ($entries as $entry) {
            if (($entry['state'] ?? '') !== 'confirmed') {
                continue;
            }
            $id = (int)($entry['id'] ?? 0);
            if ($id <= 0 || isset($ids[$id])) {
                return ['ok' => false, 'message' => 'A bracket needs different confirmed entries'];
            }
            $ids[$id] = true;
        }
        $ordered = array_keys($ids);
        sort($ordered, SORT_NUMERIC);
        if (count($ordered) < 2) {
            return ['ok' => false, 'message' => 'A bracket needs at least two confirmed entries'];
        }
        $pairs = [];
        $index = 0;
        $count = count($ordered);
        while ($index + 1 < $count) {
            $pairs[] = ['home' => $ordered[$index], 'away' => $ordered[$index + 1]];
            $index += 2;
        }
        return [
            'ok' => true,
            'pairs' => $pairs,
            'bye' => $index < $count ? $ordered[$index] : null,
        ];
    }

    public static function score(int $homeId, int $awayId, int $winnerId, int $homeScore, int $awayScore, bool $alreadyScored): array
    {
        if ($alreadyScored) {
            return ['ok' => false, 'message' => 'This match already has a result'];
        }
        if ($homeScore < 0 || $awayScore < 0) {
            return ['ok' => false, 'message' => 'Scores cannot be negative'];
        }
        if ($homeScore === $awayScore) {
            return ['ok' => false, 'message' => 'A winner needs a higher score'];
        }
        $leading = $homeScore > $awayScore ? $homeId : $awayId;
        if ($winnerId !== $leading || ($winnerId !== $homeId && $winnerId !== $awayId)) {
            return ['ok' => false, 'message' => 'The winner must have the higher score'];
        }
        return ['ok' => true, 'status' => 'completed'];
    }

    /**
     * The latest Round N must be finished. Winners and byes are paired in match order.
     * One player left is the champion and does not get another match.
     *
     * @param list<array<string,mixed>> $matches
     * @return array{ok:bool,message?:string,round?:string|null,pairs?:list<array{home:int,away:int}>,bye?:int|null,champion?:int|null}
     */
    public static function advance(array $matches): array
    {
        $rounds = [];
        foreach ($matches as $match) {
            $label = (string)($match['round'] ?? '');
            if (preg_match('/^Round (\d+)$/', $label, $found) !== 1) {
                continue;
            }
            $rounds[(int)$found[1]][] = $match;
        }
        if ($rounds === []) {
            return ['ok' => false, 'message' => 'Build a bracket before the next round'];
        }
        ksort($rounds);
        $latest = array_key_last($rounds);
        $seen = [];
        $advancers = [];
        foreach ($rounds[$latest] as $match) {
            $status = (string)($match['status'] ?? '');
            if ($status === 'bye') {
                $id = (int)($match['home'] ?? 0);
            } elseif ($status === 'completed') {
                $id = (int)($match['winner'] ?? 0);
            } else {
                return ['ok' => false, 'message' => 'This round still has a match to score'];
            }
            if ($id <= 0 || isset($seen[$id])) {
                return ['ok' => false, 'message' => 'A player can advance only once'];
            }
            $seen[$id] = true;
            $advancers[] = $id;
        }
        if (count($advancers) < 2) {
            return [
                'ok' => true,
                'round' => null,
                'pairs' => [],
                'bye' => null,
                'champion' => $advancers[0] ?? null,
            ];
        }
        $pairs = [];
        $index = 0;
        $count = count($advancers);
        while ($index + 1 < $count) {
            $pairs[] = ['home' => $advancers[$index], 'away' => $advancers[$index + 1]];
            $index += 2;
        }
        return [
            'ok' => true,
            'round' => 'Round ' . ($latest + 1),
            'pairs' => $pairs,
            'bye' => $index < $count ? $advancers[$index] : null,
            'champion' => null,
        ];
    }
}
