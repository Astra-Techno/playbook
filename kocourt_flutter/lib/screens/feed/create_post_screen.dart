import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:kocourt_shared/kocourt_shared.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _contentCtrl = TextEditingController();
  String? _imageUrl;
  bool _posting = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1200);
    if (file == null) return;
    try {
      final formData = FormData.fromMap({'image': await MultipartFile.fromFile(file.path)});
      final res = await Api().dio.post('${Api.baseUrl}/upload', data: formData);
      if (mounted) setState(() => _imageUrl = res.data['url']);
    } catch (_) {}
  }

  Future<void> _post() async {
    if (_contentCtrl.text.trim().isEmpty) return;
    setState(() => _posting = true);
    final auth = context.read<AuthProvider>();
    try {
      await Api().post('/posts', data: {
        'user_id': auth.userId,
        'content': _contentCtrl.text.trim(),
        'image_url': _imageUrl ?? '',
      });
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to post'), backgroundColor: AppColors.error));
    }
    if (mounted) setState(() => _posting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('New Post', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          TextButton(
            onPressed: _posting ? null : _post,
            child: _posting
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Post', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _contentCtrl,
              maxLines: 6,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: "What's on your mind?",
                border: InputBorder.none,
              ),
              style: const TextStyle(fontSize: 16),
            ),
            if (_imageUrl != null) ...[
              const SizedBox(height: 16),
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(_imageUrl!, height: 200, width: double.infinity, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 8, right: 8,
                    child: GestureDetector(
                      onTap: () => setState(() => _imageUrl = null),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                        child: const Icon(Icons.close, size: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(AppIcons.camera, color: Colors.grey[600]),
              title: const Text('Add Photo', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: _pickImage,
            ),
          ],
        ),
      ),
    );
  }
}
