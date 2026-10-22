import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:kocourt_shared/kocourt_shared.dart';

class EditVenueScreen extends StatefulWidget {
  final int? courtId;
  const EditVenueScreen({super.key, this.courtId});

  @override
  State<EditVenueScreen> createState() => _EditVenueScreenState();
}

class _EditVenueScreenState extends State<EditVenueScreen> {
  bool get isCreate => widget.courtId == null;
  bool _loading = false;
  bool _saving = false;

  final _nameCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _type = 'shuttle';
  String? _imageUrl;
  final _openTimeCtrl = TextEditingController(text: '06:00');
  final _closeTimeCtrl = TextEditingController(text: '22:00');
  List<String> _amenities = [];

  static const _amenitiesList = ['Parking', 'Floodlights', 'Changing Room', 'Shower', 'Equipment Rental', 'Cafeteria', 'WiFi', 'First Aid'];

  @override
  void initState() {
    super.initState();
    if (!isCreate) _loadCourt();
  }

  Future<void> _loadCourt() async {
    setState(() => _loading = true);
    try {
      final res = await Api().get('/courts/${widget.courtId}');
      final c = res.data['court'] ?? res.data;
      _nameCtrl.text = c['name'] ?? '';
      _locationCtrl.text = c['location'] ?? '';
      _rateCtrl.text = '${c['hourly_rate'] ?? ''}';
      _descCtrl.text = c['description'] ?? '';
      _type = c['type'] ?? 'shuttle';
      _imageUrl = c['image_url'];
      _openTimeCtrl.text = c['open_time'] ?? '06:00';
      _closeTimeCtrl.text = c['close_time'] ?? '22:00';
      if (c['amenities'] is List) _amenities = List<String>.from(c['amenities']);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

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

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty || _locationCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final auth = context.read<AuthProvider>();
    try {
      final data = {
        'name': _nameCtrl.text.trim(),
        'location': _locationCtrl.text.trim(),
        'type': _type,
        'hourly_rate': _rateCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'image_url': _imageUrl ?? '',
        'open_time': _openTimeCtrl.text.trim(),
        'close_time': _closeTimeCtrl.text.trim(),
        'amenities': _amenities,
        'owner_id': auth.userId,
      };
      if (isCreate) {
        await Api().post('/courts', data: data);
      } else {
        await Api().put('/courts/${widget.courtId}', data: data);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      String msg = 'Save failed';
      if (e is DioException && e.response?.data is Map) {
        msg = e.response?.data['message'] ?? e.response?.data['error'] ?? msg;
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppColors.error));
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(isCreate ? 'Add Venue' : 'Edit Venue', style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      height: 180,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(16),
                        image: _imageUrl != null ? DecorationImage(image: NetworkImage(_imageUrl!), fit: BoxFit.cover) : null,
                      ),
                      child: _imageUrl == null
                          ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Icon(AppIcons.camera, size: 32, color: Colors.grey[400]),
                              const SizedBox(height: 8),
                              Text('Tap to add photo', style: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.w600)),
                            ])
                          : null,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _label('VENUE NAME'),
                  TextField(controller: _nameCtrl, decoration: const InputDecoration(hintText: 'e.g. KO Sports Arena')),
                  const SizedBox(height: 16),
                  _label('LOCATION'),
                  TextField(controller: _locationCtrl, decoration: const InputDecoration(hintText: 'e.g. Anna Nagar, Chennai')),
                  const SizedBox(height: 16),
                  _label('SPORT TYPE'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: sportCategories.where((c) => c.id != 'All').map((c) {
                      final sel = _type == c.id;
                      return GestureDetector(
                        onTap: () => setState(() => _type = c.id),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: sel ? Colors.black : Colors.grey[100],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(c.icon, size: 14, color: sel ? Colors.white : Colors.grey[600]),
                              const SizedBox(width: 6),
                              Text(c.label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: sel ? Colors.white : Colors.grey[600])),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  _label('HOURLY RATE (\u20B9)'),
                  TextField(controller: _rateCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: 'e.g. 500')),
                  const SizedBox(height: 16),
                  _label('DESCRIPTION'),
                  TextField(controller: _descCtrl, maxLines: 3, decoration: const InputDecoration(hintText: 'Facilities, parking, etc.')),
                  const SizedBox(height: 16),
                  _label('AMENITIES'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: _amenitiesList.map((a) {
                      final sel = _amenities.contains(a);
                      return GestureDetector(
                        onTap: () => setState(() => sel ? _amenities.remove(a) : _amenities.add(a)),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: sel ? AppColors.primary.withValues(alpha: 0.1) : Colors.grey[100],
                            borderRadius: BorderRadius.circular(20),
                            border: sel ? Border.all(color: AppColors.primary.withValues(alpha: 0.3)) : null,
                          ),
                          child: Text(a, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: sel ? AppColors.primary : Colors.grey[600])),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey[400], letterSpacing: 1.5)),
  );
}
