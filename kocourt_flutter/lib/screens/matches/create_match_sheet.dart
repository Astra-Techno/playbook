import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:kocourt_shared/kocourt_shared.dart';

class CreateMatchSheet extends StatefulWidget {
  final VoidCallback onCreated;
  const CreateMatchSheet({super.key, required this.onCreated});

  @override
  State<CreateMatchSheet> createState() => _CreateMatchSheetState();
}

class _CreateMatchSheetState extends State<CreateMatchSheet> {
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  int _playersNeeded = 2;
  String? _selectedSport;
  Map<String, dynamic>? _selectedCourt;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 18, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 19, minute: 0);
  bool _submitting = false;
  List<Map<String, dynamic>> _courts = [];
  bool _loadingCourts = true;

  @override
  void initState() {
    super.initState();
    _loadCourts();
  }

  Future<void> _loadCourts() async {
    try {
      final venues = context.read<VenueProvider>();
      final params = <String, dynamic>{};
      if (venues.userLat != null && venues.userLng != null) {
        params['lat'] = venues.userLat;
        params['lng'] = venues.userLng;
        params['radius'] = 50;
      }
      final res = await Api().get('/courts', params: params);
      _courts = List<Map<String, dynamic>>.from(
        (res.data['records'] ?? []).map((e) => Map<String, dynamic>.from(e)),
      );
    } catch (_) {}
    if (mounted) setState(() => _loadingCourts = false);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
          if (_endTime.hour <= picked.hour) {
            _endTime = TimeOfDay(hour: (picked.hour + 1).clamp(0, 23), minute: picked.minute);
          }
        } else {
          _endTime = picked;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (_selectedCourt == null) {
      context.read<ToastProvider>().error('Select a venue');
      return;
    }
    setState(() => _submitting = true);
    try {
      final date = '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
      final start = '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}:00';
      final end = '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}:00';

      await Api().post('/match-requests', data: {
        'court_id': _selectedCourt!['id'],
        'title': _titleController.text.trim().isEmpty ? 'Looking for players' : _titleController.text.trim(),
        'sport': _selectedSport ?? _selectedCourt!['type'],
        'date': date,
        'start_time': start,
        'end_time': end,
        'players_needed': _playersNeeded,
        'notes': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      });
      HapticFeedback.mediumImpact();
      if (mounted) {
        context.read<ToastProvider>().success('Match created!');
        Navigator.pop(context);
        widget.onCreated();
      }
    } catch (e) {
      if (mounted) context.read<ToastProvider>().error('Failed to create match');
    }
    if (mounted) setState(() => _submitting = false);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Create Match', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('Find players for your game', style: TextStyle(color: Colors.grey[500], fontSize: 14)),
            const SizedBox(height: 24),

            // Venue selection
            const Text('Venue', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 8),
            _loadingCourts
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                  )
                : Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _selectedCourt?['id'],
                        hint: const Text('Select venue'),
                        isExpanded: true,
                        items: _courts.map((c) => DropdownMenuItem<int>(
                          value: c['id'],
                          child: Text(c['name'] ?? '', overflow: TextOverflow.ellipsis),
                        )).toList(),
                        onChanged: (id) {
                          setState(() {
                            _selectedCourt = _courts.firstWhere((c) => c['id'] == id);
                            _selectedSport ??= _selectedCourt?['type'];
                          });
                        },
                      ),
                    ),
                  ),
            const SizedBox(height: 16),

            // Title
            const Text('Title (optional)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: 'Looking for players',
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
            ),
            const SizedBox(height: 16),

            // Sport
            const Text('Sport', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 8),
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: sportCategories.where((s) => s.id != 'All').map((sport) {
                  final selected = _selectedSport == sport.id;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedSport = sport.id),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: selected ? AppColors.primary : Colors.grey[100],
                          borderRadius: BorderRadius.circular(18),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${sport.emoji} ${sport.label}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: selected ? Colors.white : Colors.grey[700],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // Date & Time
            const Text('Date & Time', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _pickDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(14)),
                      child: Row(
                        children: [
                          Icon(AppIcons.calendarDays, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Text(
                            '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _pickTime(true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(14)),
                    child: Text(_startTime.format(context), style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text('–', style: TextStyle(color: Colors.grey[400])),
                ),
                GestureDetector(
                  onTap: () => _pickTime(false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(14)),
                    child: Text(_endTime.format(context), style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Players needed
            const Text('Players Needed', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 8),
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    if (_playersNeeded > 1) setState(() => _playersNeeded--);
                  },
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                    child: const Icon(AppIcons.minus, size: 18),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text('$_playersNeeded', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                ),
                GestureDetector(
                  onTap: () {
                    if (_playersNeeded < 30) setState(() => _playersNeeded++);
                  },
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                    child: const Icon(AppIcons.plus, size: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Notes
            const Text('Notes (optional)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Skill level, rules, etc.',
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
            ),
            const SizedBox(height: 24),

            // Submit
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                  disabledBackgroundColor: Colors.grey[300],
                ),
                child: _submitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Create Match', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
