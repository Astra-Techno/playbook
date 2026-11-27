import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:kocourt_shared/kocourt_shared.dart';
import 'create_match_sheet.dart';
import 'match_roster.dart';


class MatchesScreen extends StatefulWidget {
  const MatchesScreen({super.key});

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> {
  List<Map<String, dynamic>> _matches = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMatches();
  }

  Future<void> _loadMatches() async {
    try {
      final res = await Api().get('/match-requests');
      if (mounted) {
        setState(() {
          _matches = List<Map<String, dynamic>>.from(
            (res.data['requests'] ?? []).map((e) => Map<String, dynamic>.from(e)),
          );
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _joinMatch(int matchId) async {
    try {
      await Api().post('/match-requests/$matchId/join');
      HapticFeedback.mediumImpact();
      if (mounted) context.read<ToastProvider>().success('Joined match!');
      _loadMatches();
    } catch (e) {
      if (mounted) context.read<ToastProvider>().error('Could not join match');
    }
  }

  Future<void> _leaveMatch(int matchId) async {
    try {
      await Api().delete('/match-requests/$matchId/leave');
      HapticFeedback.lightImpact();
      if (mounted) context.read<ToastProvider>().show('Left match', type: ToastType.info);
      _loadMatches();
    } catch (e) {
      if (mounted) context.read<ToastProvider>().error('Could not leave match');
    }
  }

  Future<void> _cancelMatch(int matchId) async {
    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'Cancel match?',
      body: 'This will cancel the match for all participants.',
      cancelLabel: 'No',
      confirmLabel: 'Yes, cancel',
      destructive: true,
      icon: Icons.cancel_rounded,
    );
    if (confirmed != true) return;
    try {
      await Api().delete('/match-requests/$matchId');
      HapticFeedback.lightImpact();
      if (mounted) context.read<ToastProvider>().show('Match cancelled', type: ToastType.info);
      _loadMatches();
    } catch (e) {
      if (mounted) context.read<ToastProvider>().error('Could not cancel match');
    }
  }

  void _showCreateSheet() {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      context.read<ToastProvider>().error('Please log in first');
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreateMatchSheet(
        onCreated: () {
          _loadMatches();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Find a game'),
        centerTitle: false,
        actions: [
          GestureDetector(
            onTap: _showCreateSheet,
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(AppIcons.plus, size: 14, color: Colors.white),
                  SizedBox(width: 4),
                  Text('Create', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                ],
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _matches.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(AppIcons.users, size: 48, color: AppColors.textDisabled),
                      const SizedBox(height: 16),
                      Text(
                        'No open games yet',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Post a game and players nearby can join',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _showCreateSheet,
                        icon: const Icon(AppIcons.plus, size: 16),
                        label: const Text('Create a game', style: TextStyle(fontWeight: FontWeight.w700)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadMatches,
                  color: AppColors.primary,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _matches.length,
                    itemBuilder: (_, i) => _buildMatchCard(_matches[i]),
                  ),
                ),
    );
  }

  /// Matchday match card: sport kicker, venue, friendly day/time, squad as jerseys
  /// (each player once, open spots dashed) and one clear action.
  Widget _buildMatchCard(Map<String, dynamic> match) {
    final auth = context.read<AuthProvider>();
    final isCreator = sameUser(auth.userId, match['user_id']) || sameUser(auth.userId, match['created_by']);
    final participants = List<Map<String, dynamic>>.from(
      (match['participants'] ?? []).map((e) => Map<String, dynamic>.from(e)),
    );
    final hasJoined = participants.any((p) => sameUser(p['user_id'], auth.userId));
    final slotsNeeded = int.tryParse('${match['slots_needed'] ?? match['players_needed'] ?? 1}') ?? 1;
    final joinedCount = int.tryParse('${match['joined_count'] ?? participants.length}') ?? participants.length;
    final spotsLeft = matchSpotsLeft(slotsNeeded, joinedCount > participants.length ? joinedCount : participants.length);
    final isFull = spotsLeft == 0;
    final id = matchId(match['id']);
    final sport = (match['sport'] ?? match['sport_type'] ?? '').toString();
    final day = DateTime.tryParse('${match['date'] ?? ''}');
    final venue = '${match['court_name'] ?? ''}'.trim();
    final custom = '${match['title'] ?? ''}'.trim();
    final title = venue.isNotEmpty ? venue : (custom.isNotEmpty ? custom : 'Open game');
    final hostName = '${match['creator_name'] ?? 'a player'}'.split(' ').first;
    final host = isCreator ? "You're hosting" : 'Hosted by $hostName';
    // Host is a participant too; show each player once.
    final seen = <String>{};
    final names = [
      for (final p in participants)
        if (seen.add('${p['user_id']}')) sameUser(p['user_id'], auth.userId) ? 'You' : '${p['name'] ?? 'Player'}',
    ];
    final notes = '${match['notes'] ?? ''}'.trim();
    final hasCustomTitle = custom.isNotEmpty && custom != 'Looking for players' && !custom.startsWith('Need ');

    String? action;
    VoidCallback? onAction;
    var secondary = false;
    if (!isCreator && hasJoined && id != null) {
      action = "You're in · Leave";
      secondary = true;
      onAction = () => _leaveMatch(id);
    } else if (!isCreator && !isFull && auth.isLoggedIn && id != null) {
      action = spotsLeft == 1 ? 'Join · last spot' : 'Join game';
      onAction = () => _joinMatch(id);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: KoCard(
        sport: sport,
        kicker: sport.isEmpty ? 'Open game' : sportLabel(sport),
        title: title,
        meta: [if (day != null) friendlyDay(day), clockRange(match['start_time'], match['end_time']), host].where((t) => t.isNotEmpty).join(' · '),
        badge: isFull ? 'Full' : 'Need $spotsLeft',
        middle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasCustomTitle) ...[
              Text(custom, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
            ],
            JerseyRow(
              names: names,
              open: spotsLeft,
              tone: sportTint(sport).fg,
              note: isFull ? 'Game is full' : '$spotsLeft spot${spotsLeft == 1 ? '' : 's'} left',
            ),
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(notes, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ],
            if (isCreator && id != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => _cancelMatch(id),
                  style: TextButton.styleFrom(foregroundColor: AppColors.error, padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                  child: const Text('Cancel game'),
                ),
              ),
          ],
        ),
        actionLabel: action,
        secondaryAction: secondary,
        onAction: onAction,
      ),
    );
  }
}
