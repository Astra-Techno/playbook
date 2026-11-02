<?php

/** A venue class. The instructor is a name. A full class refuses another player. */
final class CoachingSession
{
    /** @return array{ok:bool,message?:string,title?:string,instructor?:string,capacity?:int,start?:string,end?:string} */
    public static function plan(string $title, string $instructor, int $capacity, string $start, string $end, bool $slotFree): array
    {
        $title = trim($title);
        $instructor = trim($instructor);
        if ($title === '' || strlen($title) > 120) {
            return ['ok' => false, 'message' => 'Add a class name within 120 characters.'];
        }
        if ($instructor === '' || strlen($instructor) > 80) {
            return ['ok' => false, 'message' => 'Add the instructor name within 80 characters.'];
        }
        if ($capacity < 1 || $capacity > 200) {
            return ['ok' => false, 'message' => 'Capacity must be from 1 to 200.'];
        }
        if (!preg_match('/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$/', $start) || !preg_match('/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$/', $end)) {
            return ['ok' => false, 'message' => 'Start and end must be dates and times.'];
        }
        if ($end <= $start) {
            return ['ok' => false, 'message' => 'The end must be after the start.'];
        }
        if (!$slotFree) {
            return ['ok' => false, 'message' => 'That court already has a booking or a closure in these times.'];
        }
        return [
            'ok' => true,
            'title' => $title,
            'instructor' => $instructor,
            'capacity' => $capacity,
            'start' => $start,
            'end' => $end,
        ];
    }

    public static function canCancel(string $status): bool
    {
        return $status === 'scheduled';
    }

    /**
     * @param list<int> $enrolledUserIds
     * @return array{ok:bool,message?:string,name?:string,user_id?:int|null}
     */
    public static function enroll(string $sessionStatus, int $capacity, int $taken, string $name, ?int $userId, array $enrolledUserIds): array
    {
        if ($sessionStatus !== 'scheduled') {
            return ['ok' => false, 'message' => 'This class is not taking players.'];
        }
        $name = trim($name);
        if ($name === '' || strlen($name) > 80) {
            return ['ok' => false, 'message' => 'Add the player name within 80 characters.'];
        }
        if ($userId !== null && $userId <= 0) {
            $userId = null;
        }
        if ($userId !== null && in_array($userId, $enrolledUserIds, true)) {
            return ['ok' => false, 'message' => 'This player is already in the class.'];
        }
        if ($taken >= $capacity) {
            return ['ok' => false, 'message' => 'This class is full.'];
        }
        return ['ok' => true, 'name' => $name, 'user_id' => $userId];
    }

    /** @return array{ok:bool,message?:string,attendance?:string} */
    public static function attendance(string $sessionStatus, string $enrollmentState, ?string $current, string $mark): array
    {
        if ($sessionStatus !== 'scheduled' || $enrollmentState !== 'enrolled') {
            return ['ok' => false, 'message' => 'Only a player in a scheduled class can be marked.'];
        }
        if ($current !== null && $current !== '') {
            return ['ok' => false, 'message' => 'Attendance is already marked.'];
        }
        if ($mark !== 'present' && $mark !== 'absent') {
            return ['ok' => false, 'message' => 'Mark the player present or absent.'];
        }
        return ['ok' => true, 'attendance' => $mark];
    }
}
