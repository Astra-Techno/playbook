<?php

/** Organizer decision on an entry that is waiting for approval. */
final class TournamentApproval
{
    /** @return array{ok:bool,message:string,state?:string} */
    public static function decide(string $state, string $action): array
    {
        if ($state !== 'pending_approval') {
            return ['ok' => false, 'message' => 'Only an entry waiting for approval can be reviewed.'];
        }
        if ($action === 'approve') {
            return ['ok' => true, 'state' => 'confirmed', 'message' => 'Entry approved.'];
        }
        if ($action === 'reject') {
            return ['ok' => true, 'state' => 'cancelled', 'message' => 'Entry rejected.'];
        }
        return ['ok' => false, 'message' => 'action must be approve or reject.'];
    }
}
