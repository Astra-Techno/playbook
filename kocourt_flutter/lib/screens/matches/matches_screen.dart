import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:kocourt_shared/kocourt_shared.dart';
import 'create_match_sheet.dart';


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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Match?', style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('This will cancel the match for all participants.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Cancel', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Find a Game', style: TextStyle(fontWeight: FontWeight.w800)),
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
                      Icon(AppIcons.users, size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        'No open matches',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.grey[700]),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Create one and find players',
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _showCreateSheet,
                        icon: const Icon(AppIcons.plus, size: 16),
                        label: const Text('Create Match', style: TextStyle(fontWeight: FontWeight.w700)),
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

  Widget _buildMatchCard(Map<String, dynamic> match) {
    final auth = context.read<AuthProvider>();
    final isCreator = auth.userId == match['user_id'] || auth.userId == match['created_by'];
    final participants = List<Map<String, dynamic>>.from(
      (match['participants'] ?? []).map((e) => Map<String, dynamic>.from(e)),
    );
    final hasJoined = participants.any((p) => p['user_id'] == auth.userId);
    final isFull = match['status'] == 'full';
    final slotsNeeded = int.tryParse('${match['slots_needed'] ?? match['players_needed'] ?? 0}') ?? 0;
    final joinedCount = int.tryParse('${match['joined_count'] ?? participants.length}') ?? participants.length;
    final spotsLeft = slotsNeeded - joinedCount + 1; // +1 because creator auto-joins

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[100]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (match['sport'] != null || match['sport_type'] != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    (match['sport'] ?? match['sport_type'] ?? '').toString().toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              const Spacer(),
              if (isFull)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('FULL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.orange)),
                )
              else
                Text(
                  match['date'] ?? '',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            match['title'] ?? match['court_name'] ?? 'Looking for players',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          if (match['court_name'] != null && match['title'] != null) ...[
            const SizedBox(height: 2),
            Text(
              match['court_name'],
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(AppIcons.calendarDays, size: 13, color: Colors.grey[400]),
              const SizedBox(width: 4),
              Text(
                match['date'] ?? '',
                style: TextStyle(fontSize: 13, color: Colors.grey[500]),
              ),
              const SizedBox(width: 16),
              Icon(AppIcons.clock, size: 13, color: Colors.grey[400]),
              const SizedBox(width: 4),
              Text(
                '${_formatTime(match['start_time'])} - ${_formatTime(match['end_time'])}',
                style: TextStyle(fontSize: 13, color: Colors.grey[500]),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(AppIcons.users, size: 13, color: Colors.grey[400]),
              const SizedBox(width: 4),
              Text(
                isFull ? 'Match is full' : '$spotsLeft spot${spotsLeft == 1 ? '' : 's'} left',
                style: TextStyle(
                  fontSize: 13,
                  color: isFull ? Colors.orange : Colors.grey[500],
                  fontWeight: isFull ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
          if (participants.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 28,
              child: Row(
                children: [
                  ...participants.take(5).map((p) => Container(
                    margin: const EdgeInsets.only(right: 4),
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: p['avatar_url'] != null ? NetworkImage(p['avatar_url']) : null,
                      child: p['avatar_url'] == null
                          ? Text(
                              (p['name'] ?? '?')[0].toUpperCase(),
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                            )
                          : null,
                    ),
                  )),
                  if (participants.length > 5)
                    Text(
                      '+${participants.length - 5}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w600),
                    ),
                ],
              ),
            ),
          ],
          if (match['notes']?.toString().isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Text(
              match['notes'],
              style: TextStyle(fontSize: 13, color: Colors.grey[500], fontStyle: FontStyle.italic),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: Colors.grey[200],
                backgroundImage: match['creator_avatar'] != null ? NetworkImage(match['creator_avatar']) : null,
                child: match['creator_avatar'] == null
                    ? Text(
                        (match['creator_name'] ?? '?')[0].toUpperCase(),
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                      )
                    : null,
              ),
              const SizedBox(width: 8),
              Text(
                isCreator ? 'You' : (match['creator_name'] ?? 'Player'),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[600]),
              ),
              const Spacer(),
              if (isCreator)
                SizedBox(
                  height: 36,
                  child: OutlinedButton(
                    onPressed: () => _cancelMatch(match['id']),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: const Text('Cancel', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  ),
                )
              else if (hasJoined)
                SizedBox(
                  height: 36,
                  child: OutlinedButton(
                    onPressed: () => _leaveMatch(match['id']),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey[600],
                      side: BorderSide(color: Colors.grey[300]!),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: const Text('Leave', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  ),
                )
              else if (!isFull && auth.isLoggedIn)
                SizedBox(
                  height: 36,
                  child: ElevatedButton(
                    onPressed: () => _joinMatch(match['id']),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                    ),
                    child: const Text('Join', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTime(String? time) {
    if (time == null || time.isEmpty) return '';
    final parts = time.split(':');
    if (parts.length < 2) return time;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = parts[1];
    final period = h >= 12 ? 'PM' : 'AM';
    final hour = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$hour:$m $period';
  }
}
