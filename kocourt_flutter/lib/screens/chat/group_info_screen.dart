import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:kocourt_shared/kocourt_shared.dart';
import 'new_chat_screen.dart';

class GroupInfoScreen extends StatefulWidget {
  final int groupId;
  const GroupInfoScreen({super.key, required this.groupId});

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  Map<String, dynamic>? _group;
  List<Map<String, dynamic>> _members = [];
  bool _loading = true;
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await Api().get('/chat/groups/${widget.groupId}');
      final group = Map<String, dynamic>.from(res.data['group'] ?? {});
      final members = List<Map<String, dynamic>>.from(
        (group['members'] ?? []).map((e) => Map<String, dynamic>.from(e)),
      );
      if (mounted) {
        setState(() {
          _group = group;
          _members = members;
          _loading = false;
          // Find current user's mute status
          final auth = context.read<AuthProvider>();
          final me = members.where((m) => m['id'] == auth.userId).firstOrNull;
          _isMuted = me?['muted'] == 1 || me?['muted'] == true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _isAdmin() {
    final auth = context.read<AuthProvider>();
    return _members.any((m) => m['id'] == auth.userId && m['role'] == 'admin');
  }

  Future<void> _editGroup() async {
    final nameCtrl = TextEditingController(text: _group?['name'] ?? '');
    final descCtrl = TextEditingController(text: _group?['description'] ?? '');

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Group'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Group name')),
            const SizedBox(height: 12),
            TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description'), maxLines: 3),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, {'name': nameCtrl.text.trim(), 'description': descCtrl.text.trim()}),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    nameCtrl.dispose();
    descCtrl.dispose();

    if (result != null && result['name']!.isNotEmpty) {
      try {
        await Api().put('/chat/groups/${widget.groupId}', data: result);
        _load();
      } catch (_) {}
    }
  }

  Future<void> _addMembers() async {
    final result = await Navigator.push<List<int>>(
      context,
      MaterialPageRoute(builder: (_) => NewChatScreen(pickOnly: true, excludeIds: _members.map((m) => m['id'] as int).toList())),
    );
    if (result != null && result.isNotEmpty) {
      try {
        await Api().post('/chat/groups/${widget.groupId}/members', data: {'user_ids': result});
        _load();
      } catch (_) {}
    }
  }

  Future<void> _removeMember(int userId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove member'),
        content: Text('Remove $name from this group?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await Api().delete('/chat/groups/${widget.groupId}/members/$userId');
        _load();
      } catch (_) {}
    }
  }

  Future<void> _leaveGroup() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave group'),
        content: const Text('Are you sure you want to leave this group?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final auth = context.read<AuthProvider>();
      try {
        await Api().delete('/chat/groups/${widget.groupId}/members/${auth.userId}');
        if (mounted) {
          Navigator.pop(context);
          Navigator.pop(context);
        }
      } catch (_) {}
    }
  }

  Future<void> _toggleMute() async {
    try {
      await Api().put('/chat/groups/${widget.groupId}/mute', data: {'muted': !_isMuted});
      if (mounted) setState(() => _isMuted = !_isMuted);
      HapticFeedback.selectionClick();
    } catch (_) {}
  }

  Future<void> _deleteGroup() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete group'),
        content: const Text('This will permanently delete the group and all messages.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await Api().delete('/chat/groups/${widget.groupId}');
        if (mounted) {
          Navigator.pop(context);
          Navigator.pop(context);
        }
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isDm = _group?['type'] == 'dm';
    final isAdmin = _isAdmin();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(isDm ? 'Chat Info' : 'Group Info', style: const TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        actions: [
          if (isAdmin && !isDm)
            IconButton(icon: const Icon(Icons.edit_rounded, size: 20), onPressed: _editGroup),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : ListView(
              children: [
                // Group header
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                        backgroundImage: _group?['icon_url'] != null ? NetworkImage(_group!['icon_url']) : null,
                        child: _group?['icon_url'] == null
                            ? Icon(isDm ? Icons.person_rounded : Icons.group_rounded, size: 36, color: AppColors.primary)
                            : null,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _group?['name'] ?? (isDm ? (_members.where((m) => m['id'] != auth.userId).firstOrNull?['name'] ?? 'Chat') : 'Group'),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                        textAlign: TextAlign.center,
                      ),
                      if (_group?['description'] != null && _group!['description'].toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(_group!['description'], style: TextStyle(color: Colors.grey[600], fontSize: 14), textAlign: TextAlign.center),
                        ),
                      const SizedBox(height: 4),
                      Text('${_members.length} members', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                    ],
                  ),
                ),

                // Actions
                Divider(color: Colors.grey[100], height: 1),
                ListTile(
                  leading: Icon(_isMuted ? Icons.notifications_off_rounded : Icons.notifications_rounded, color: Colors.grey[600]),
                  title: Text(_isMuted ? 'Unmute notifications' : 'Mute notifications'),
                  onTap: _toggleMute,
                ),
                if (!isDm) ...[
                  Divider(color: Colors.grey[100], height: 1),

                  // Members header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                    child: Row(
                      children: [
                        Text('Members', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.grey[700])),
                        const Spacer(),
                        if (isAdmin)
                          GestureDetector(
                            onTap: _addMembers,
                            child: Row(
                              children: [
                                const Icon(Icons.person_add_rounded, size: 16, color: AppColors.primary),
                                const SizedBox(width: 4),
                                const Text('Add', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Members list
                  ...(_members.map((m) {
                    final isMe = m['id'] == auth.userId;
                    final memberIsAdmin = m['role'] == 'admin';
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.grey[200],
                        backgroundImage: m['avatar_url'] != null ? NetworkImage(m['avatar_url']) : null,
                        child: m['avatar_url'] == null
                            ? Text(
                                (m['name'] ?? '?')[0].toUpperCase(),
                                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary),
                              )
                            : null,
                      ),
                      title: Row(
                        children: [
                          Flexible(child: Text(isMe ? 'You' : (m['name'] ?? 'User'), style: const TextStyle(fontWeight: FontWeight.w600))),
                          if (memberIsAdmin) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                              child: const Text('Admin', style: TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ],
                      ),
                      subtitle: m['phone'] != null ? Text(m['phone'], style: TextStyle(fontSize: 12, color: Colors.grey[500])) : null,
                      trailing: isAdmin && !isMe
                          ? IconButton(
                              icon: Icon(Icons.remove_circle_outline_rounded, color: Colors.red[300], size: 20),
                              onPressed: () => _removeMember(m['id'], m['name'] ?? 'User'),
                            )
                          : null,
                    );
                  })),
                ],

                // Leave / Delete
                const SizedBox(height: 24),
                Divider(color: Colors.grey[100], height: 1),
                if (!isDm)
                  ListTile(
                    leading: const Icon(Icons.exit_to_app_rounded, color: Colors.red),
                    title: const Text('Leave group', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                    onTap: _leaveGroup,
                  ),
                if (isAdmin && !isDm)
                  ListTile(
                    leading: const Icon(Icons.delete_rounded, color: Colors.red),
                    title: const Text('Delete group', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                    onTap: _deleteGroup,
                  ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }
}
