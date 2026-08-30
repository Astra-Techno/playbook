import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/api.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import 'slot_chat_screen.dart';

class SlotGroupsScreen extends StatefulWidget {
  const SlotGroupsScreen({super.key});

  @override
  State<SlotGroupsScreen> createState() => _SlotGroupsScreenState();
}

class _SlotGroupsScreenState extends State<SlotGroupsScreen> {
  List<Map<String, dynamic>> _groups = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    try {
      final res = await Api().get('/slot-chat/my-groups');
      _groups = List<Map<String, dynamic>>.from(
        (res.data['groups'] ?? []).map((e) => Map<String, dynamic>.from(e)),
      );
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  String _formatSlotTime(String? time) {
    if (time == null) return '';
    try {
      final parts = time.split(':');
      final h = int.parse(parts[0]);
      final m = parts[1];
      final period = h >= 12 ? 'PM' : 'AM';
      final hour = h == 0 ? 12 : (h > 12 ? h - 12 : h);
      return '$hour:$m $period';
    } catch (_) {
      return time;
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final d = DateTime.parse(dateStr);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));
      final date = DateTime(d.year, d.month, d.day);
      if (date == today) return 'Today';
      if (date == tomorrow) return 'Tomorrow';
      return DateFormat('EEE, MMM d').format(d);
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Slot Groups', style: TextStyle(fontWeight: FontWeight.w800)),
        centerTitle: false,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      body: !auth.isLoggedIn
          ? const Center(child: Text('Login to see your slot groups'))
          : _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : _groups.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.forum_rounded, size: 48, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text(
                            'No active slot groups',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.grey[700]),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Book a court to join a group chat with\nother players in your time slot',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey[400], fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async {
                        setState(() => _loading = true);
                        await _loadGroups();
                      },
                      color: AppColors.primary,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _groups.length,
                        itemBuilder: (_, i) => _buildGroupCard(_groups[i]),
                      ),
                    ),
    );
  }

  Widget _buildGroupCard(Map<String, dynamic> group) {
    final courtName = group['court_name'] ?? 'Court';
    final slotDate = group['slot_date'] ?? '';
    final slotTime = group['slot_time'] ?? '';
    final slotEndTime = group['slot_end_time'] ?? '';
    final playerCount = int.tryParse('${group['player_count'] ?? 0}') ?? 0;
    final messageCount = int.tryParse('${group['message_count'] ?? 0}') ?? 0;
    final lastMessage = group['last_message'];
    final lastSender = group['last_sender_name'];

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => SlotChatScreen(
            courtId: group['court_id'] is int ? group['court_id'] : int.parse('${group['court_id']}'),
            date: slotDate,
            time: slotTime,
            courtName: courtName,
            slotLabel: '${_formatDate(slotDate)} \u00B7 ${_formatSlotTime(slotTime)} - ${_formatSlotTime(slotEndTime)}',
          ),
        )).then((_) => _loadGroups());
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Sport icon
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.forum_rounded, color: AppColors.secondary, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      courtName,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(Icons.schedule_rounded, size: 12, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Text(
                          '${_formatDate(slotDate)} \u00B7 ${_formatSlotTime(slotTime)}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    if (lastMessage != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        '${lastSender ?? 'Someone'}: $lastMessage',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Player count badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.person_rounded, size: 13, color: AppColors.textMuted),
                        const SizedBox(width: 3),
                        Text(
                          '$playerCount',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  if (messageCount > 0) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$messageCount msg${messageCount != 1 ? 's' : ''}',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
