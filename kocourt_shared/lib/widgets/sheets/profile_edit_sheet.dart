import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../../core/api.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';

class ProfileEditSheet extends StatefulWidget {
  const ProfileEditSheet({super.key});

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ProfileEditSheet(),
    );
  }

  @override
  State<ProfileEditSheet> createState() => _ProfileEditSheetState();
}

class _ProfileEditSheetState extends State<ProfileEditSheet> {
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  String? _skillLevel;
  bool _saving = false;

  static const _skillLevels = ['beginner', 'intermediate', 'advanced', 'pro'];

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _nameController.text = auth.userName;
    _bioController.text = auth.userBio ?? '';
    _skillLevel = auth.skillLevel;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 600);
    if (file == null) return;

    try {
      final auth = context.read<AuthProvider>();
      final res = await Api().uploadFile('/upload', File(file.path));
      final url = res.data['url'] ?? res.data['file_url'];
      if (url != null) {
        await auth.updateAvatar(url);
      }
    } catch (_) {}
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _saving = true);
    try {
      final auth = context.read<AuthProvider>();
      await Api().put('/auth/profile', data: {
        'user_id': auth.userId,
        'name': name,
        'bio': _bioController.text.trim(),
        'skill_level': _skillLevel,
      });
      await auth.refreshUser();
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.textDisabled, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Edit Profile', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 20),

          // Avatar
          Center(
            child: GestureDetector(
              onTap: _pickAvatar,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: AppColors.surface,
                    backgroundImage: auth.avatarUrl != null ? NetworkImage(auth.avatarUrl!) : null,
                    child: auth.avatarUrl == null
                        ? Text(
                            auth.userName.isNotEmpty ? auth.userName[0].toUpperCase() : '?',
                            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.primary),
                          )
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Name'),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bioController,
            decoration: const InputDecoration(labelText: 'Bio (optional)'),
            maxLines: 2,
          ),
          const SizedBox(height: 12),

          // Skill level
          DropdownButtonFormField<String>(
            value: _skillLevel,
            decoration: const InputDecoration(labelText: 'Skill Level'),
            items: _skillLevels.map((s) => DropdownMenuItem(
              value: s,
              child: Text(s[0].toUpperCase() + s.substring(1)),
            )).toList(),
            onChanged: (v) => setState(() => _skillLevel = v),
          ),
          const SizedBox(height: 24),

          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}
