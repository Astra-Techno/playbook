import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:kocourt_shared/kocourt_shared.dart';

class ClaimVenueSheet extends StatefulWidget {
  final Map<String, dynamic> place;
  final int userId;

  const ClaimVenueSheet({super.key, required this.place, required this.userId});

  static Future<bool?> show(BuildContext context, Map<String, dynamic> place, int userId) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ClaimVenueSheet(place: place, userId: userId),
    );
  }

  @override
  State<ClaimVenueSheet> createState() => _ClaimVenueSheetState();
}

class _ClaimVenueSheetState extends State<ClaimVenueSheet> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _proofImageUrl;
  bool _uploading = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.place['name'] ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickProofImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1200);
    if (file == null) return;

    setState(() => _uploading = true);
    try {
      final res = await Api().uploadFile('/upload', File(file.path));
      setState(() {
        _proofImageUrl = res.data['url'] ?? res.data['file_url'];
        _uploading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _submit() async {
    if (_nameController.text.trim().isEmpty) return;

    setState(() => _submitting = true);
    try {
      await Api().post('/courts/claim', data: {
        'user_id': widget.userId,
        'place_name': _nameController.text.trim(),
        'place_id': widget.place['place_id'] ?? widget.place['id'],
        'phone': _phoneController.text.trim(),
        'proof_image': _proofImageUrl,
        'lat': widget.place['lat'],
        'lng': widget.place['lng'],
      });
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
              decoration: BoxDecoration(
                color: AppColors.textDisabled,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Claim This Venue', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          const Text(
            'Prove you own or manage this venue',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 20),

          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Venue Name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Your Phone Number'),
          ),
          const SizedBox(height: 16),

          // Proof image
          GestureDetector(
            onTap: _uploading ? null : _pickProofImage,
            child: Container(
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.border),
              ),
              child: _uploading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : _proofImageUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          child: Image.network(_proofImageUrl!, fit: BoxFit.cover, width: double.infinity),
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined, size: 28, color: AppColors.textMuted),
                            SizedBox(height: 4),
                            Text('Upload proof (ID, license, etc.)', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                          ],
                        ),
            ),
          ),
          const SizedBox(height: 20),

          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Submit Claim', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}
