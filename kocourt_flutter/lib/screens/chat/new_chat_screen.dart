import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kocourt_shared/kocourt_shared.dart';

/// Used for:
/// 1. Creating a new DM or group (default)
/// 2. Picking members to add to an existing group (pickOnly=true)
class NewChatScreen extends StatefulWidget {
  final bool pickOnly;
  final List<int> excludeIds;

  const NewChatScreen({super.key, this.pickOnly = false, this.excludeIds = const []});

  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  final Set<int> _selected = {};
  bool _searching = false;
  bool _isGroup = false;
  bool _creating = false;
  final _nameCtrl = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _nameCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(q));
  }

  Future<void> _search(String q) async {
    if (q.length < 2) {
      if (mounted) setState(() => _results = []);
      return;
    }
    setState(() => _searching = true);
    try {
      final res = await Api().get('/chat/users/search', params: {'q': q});
      final users = List<Map<String, dynamic>>.from(
        (res.data['users'] ?? []).map((e) => Map<String, dynamic>.from(e)),
      );
      // Filter out excluded IDs
      if (widget.excludeIds.isNotEmpty) {
        users.removeWhere((u) => widget.excludeIds.contains(u['id']));
      }
      if (mounted) setState(() => _results = users);
    } catch (_) {}
    if (mounted) setState(() => _searching = false);
  }

  void _toggleUser(int userId) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selected.contains(userId)) {
        _selected.remove(userId);
      } else {
        _selected.add(userId);
      }
      // Auto-switch to group mode when 2+ selected
      if (_selected.length > 1) _isGroup = true;
    });
  }

  Future<void> _create() async {
    if (_selected.isEmpty) return;

    // If pickOnly, return selected IDs
    if (widget.pickOnly) {
      Navigator.pop(context, _selected.toList());
      return;
    }

    // DM: one user, no name needed
    if (!_isGroup && _selected.length == 1) {
      setState(() => _creating = true);
      try {
        final res = await Api().post('/chat/groups', data: {
          'type': 'dm',
          'member_ids': _selected.toList(),
        });
        final groupId = res.data['group_id'];
        if (mounted) Navigator.pop(context, groupId);
      } catch (_) {
        if (mounted) setState(() => _creating = false);
      }
      return;
    }

    // Group: need name
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a group name'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _creating = true);
    try {
      final res = await Api().post('/chat/groups', data: {
        'type': 'group',
        'name': _nameCtrl.text.trim(),
        'member_ids': _selected.toList(),
      });
      final groupId = res.data['group_id'];
      if (mounted) Navigator.pop(context, groupId);
    } catch (_) {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.pickOnly ? 'Add Members' : (_isGroup ? 'New Group' : 'New Chat');

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        actions: [
          if (_selected.isNotEmpty)
            TextButton(
              onPressed: _creating ? null : _create,
              child: _creating
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                  : Text(
                      widget.pickOnly ? 'Add (${_selected.length})' : (_isGroup ? 'Create' : 'Chat'),
                      style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary),
                    ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Group name (only in group mode, not pickOnly)
          if (_isGroup && !widget.pickOnly)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: TextField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  hintText: 'Group name',
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),

          // Selected chips
          if (_selected.isNotEmpty)
            SizedBox(
              height: 50,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: _selected.map((id) {
                  final user = _results.where((u) => u['id'] == id).firstOrNull;
                  final name = user?['name'] ?? 'User';
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Chip(
                      label: Text(name, style: const TextStyle(fontSize: 12)),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () => _toggleUser(id),
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      side: BorderSide.none,
                    ),
                  );
                }).toList(),
              ),
            ),

          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search by name or phone...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),

          // Toggle group mode
          if (!widget.pickOnly && _selected.length <= 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Checkbox(
                    value: _isGroup,
                    onChanged: (v) => setState(() => _isGroup = v ?? false),
                    activeColor: AppColors.primary,
                  ),
                  const Text('Create group chat', style: TextStyle(fontSize: 14)),
                ],
              ),
            ),

          // Results
          Expanded(
            child: _searching
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _results.isEmpty
                    ? Center(
                        child: Text(
                          _searchCtrl.text.length < 2 ? 'Type to search users' : 'No users found',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _results.length,
                        itemBuilder: (_, i) {
                          final user = _results[i];
                          final userId = user['id'] as int;
                          final isSelected = _selected.contains(userId);
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.grey[200],
                              backgroundImage: user['avatar_url'] != null ? NetworkImage(user['avatar_url']) : null,
                              child: user['avatar_url'] == null
                                  ? Text(
                                      (user['name'] ?? '?')[0].toUpperCase(),
                                      style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary),
                                    )
                                  : null,
                            ),
                            title: Text(user['name'] ?? 'User', style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: user['phone'] != null
                                ? Text(user['phone'], style: TextStyle(fontSize: 12, color: Colors.grey[500]))
                                : null,
                            trailing: isSelected
                                ? const Icon(Icons.check_circle_rounded, color: AppColors.primary)
                                : Icon(Icons.circle_outlined, color: Colors.grey[300]),
                            onTap: () => _toggleUser(userId),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
