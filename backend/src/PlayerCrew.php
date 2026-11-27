<?php

/**
 * "Your crew" on the player home: the people you play with, built from booking
 * squads (bookers + booking_players). Names and avatars only, never phones.
 */
final class PlayerCrew
{
    public const MAX_MATES = 12;

    /**
     * @param list<array{id:int|string,user_id:int|string,court_id:int|string,sub_court_id:mixed,start_time:string,end_time:string,court_name?:string,court_type?:string}> $bookings
     *        Confirmed games the caller booked or played in, newest first.
     * @param array<int, list<int>> $playersByBooking booking id => player user ids
     * @param array<int, array{id:int|string,name:string,avatar_url:?string}> $people user id => public profile
     * @return array{mates:list<array<string,mixed>>, rebook:?array<string,mixed>}
     */
    public static function build(array $bookings, array $playersByBooking, array $people, int $me, string $now): array
    {
        $mates = [];
        $rebook = null;
        foreach ($bookings as $b) {
            $bid = (int)$b['id'];
            $members = array_values(array_unique(array_merge([(int)$b['user_id']], array_map('intval', $playersByBooking[$bid] ?? []))));
            if (!in_array($me, $members, true)) continue;
            $played = $b['end_time'] <= $now;
            foreach ($members as $uid) {
                if ($uid === $me || !isset($people[$uid])) continue;
                $m = $mates[$uid] ?? ['id' => $uid, 'name' => (string)$people[$uid]['name'], 'avatar_url' => $people[$uid]['avatar_url'] ?? null, 'games' => 0, 'last_played' => null];
                if ($played) {
                    $m['games']++;
                    if ($m['last_played'] === null || $b['start_time'] > $m['last_played']) $m['last_played'] = $b['start_time'];
                }
                $mates[$uid] = $m;
            }
            // Rebook: the latest finished game I booked that had other players.
            if ($rebook === null && $played && (int)$b['user_id'] === $me && count($members) > 1) {
                $others = array_values(array_filter($members, fn ($u) => $u !== $me && isset($people[$u])));
                if ($others) {
                    [$start, $end] = self::nextSameSlot($b['start_time'], $b['end_time'], $now);
                    $rebook = [
                        'court_id' => (int)$b['court_id'],
                        'court_name' => (string)($b['court_name'] ?? ''),
                        'court_type' => (string)($b['court_type'] ?? ''),
                        'sub_court_id' => $b['sub_court_id'] === null ? null : (int)$b['sub_court_id'],
                        'start_time' => $start,
                        'end_time' => $end,
                        'last_played' => $b['start_time'],
                        'player_ids' => $others,
                        'player_names' => array_map(fn ($u) => (string)$people[$u]['name'], $others),
                    ];
                }
            }
        }
        $mates = array_values(array_filter($mates, fn ($m) => $m['games'] > 0));
        usort($mates, fn ($a, $b) => [$b['games'], (string)$b['last_played']] <=> [$a['games'], (string)$a['last_played']]);
        return ['mates' => array_slice($mates, 0, self::MAX_MATES), 'rebook' => $rebook];
    }

    /**
     * Confirmed games $me booked or played in since $since (walk-ins excluded), their squads and
     * the public profiles of everyone involved — the input for build() and PlayerStats.
     * @return array{0:list<array<string,mixed>>,1:array<int,list<int>>,2:array<int,array<string,mixed>>}
     */
    public static function load(PDO $db, int $me, string $since): array
    {
        $stmt = $db->prepare(
            "SELECT b.id, b.user_id, b.court_id, b.sub_court_id, b.start_time, b.end_time, b.attendance, c.name AS court_name, c.type AS court_type
             FROM bookings b JOIN courts c ON c.id = b.court_id
             WHERE b.status = 'confirmed' AND b.guest_name IS NULL AND b.start_time >= ?
               AND (b.user_id = ? OR b.id IN (SELECT booking_id FROM booking_players WHERE user_id = ?))
             ORDER BY b.start_time DESC LIMIT 400"
        );
        $stmt->execute([$since, $me, $me]);
        $bookings = $stmt->fetchAll(PDO::FETCH_ASSOC);
        $playersByBooking = [];
        $ids = [$me => true];
        if ($bookings) {
            $bids = array_map(fn ($b) => (int)$b['id'], $bookings);
            $marks = implode(',', array_fill(0, count($bids), '?'));
            $p = $db->prepare("SELECT booking_id, user_id FROM booking_players WHERE booking_id IN ($marks)");
            $p->execute($bids);
            foreach ($p->fetchAll(PDO::FETCH_ASSOC) as $row) {
                $playersByBooking[(int)$row['booking_id']][] = (int)$row['user_id'];
                $ids[(int)$row['user_id']] = true;
            }
            foreach ($bookings as $b) $ids[(int)$b['user_id']] = true;
        }
        $people = [];
        $uids = array_keys($ids);
        $marks = implode(',', array_fill(0, count($uids), '?'));
        $u = $db->prepare("SELECT id, name, avatar_url FROM users WHERE id IN ($marks)");
        $u->execute($uids);
        foreach ($u->fetchAll(PDO::FETCH_ASSOC) as $row) $people[(int)$row['id']] = $row;
        return [$bookings, $playersByBooking, $people];
    }

    /**
     * The same weekday and time as a past game, at the first occurrence after $now.
     * @return array{0:string,1:string}
     */
    public static function nextSameSlot(string $start, string $end, string $now): array
    {
        $s = new DateTimeImmutable($start);
        $length = (new DateTimeImmutable($end))->getTimestamp() - $s->getTimestamp();
        $n = new DateTimeImmutable($now);
        $next = $n->setTime((int)$s->format('H'), (int)$s->format('i'));
        $days = ((int)$s->format('w') - (int)$n->format('w') + 7) % 7;
        $next = $next->modify("+{$days} days");
        if ($next <= $n) $next = $next->modify('+7 days');
        return [$next->format('Y-m-d H:i:s'), $next->modify("+{$length} seconds")->format('Y-m-d H:i:s')];
    }
}
