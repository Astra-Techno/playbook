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
    return AppSheetScaffold(
      child: FormGap(
        children: [
          Text('Claim this venue', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: context.brand.ink)),
          const Text(
            'Prove you own or manage this venue',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          AppTextField(controller: _nameController, label: 'Venue name'),
          PhoneField(controller: _phoneController, label: 'Your mobile number'),
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
                  ? Center(child: CircularProgressIndicator(color: context.brandPrimary))
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
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Submit claim', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}
