import 'package:flutter/material.dart';
import 'package:kocourt_shared/kocourt_shared.dart';
import '../../widgets/tab_status.dart';
import 'coaching_fields.dart';

class VenueCoachingScreen extends StatefulWidget {
  final int courtId;
  const VenueCoachingScreen({super.key, required this.courtId});

  @override
  State<VenueCoachingScreen> createState() => _VenueCoachingScreenState();
}

class _VenueCoachingScreenState extends State<VenueCoachingScreen> {
  bool _loading = true;
  bool _acting = false;
  String? _error;
  List<Map<String, dynamic>> _sessions = const [];
  final _title = TextEditingController();
  final _instructor = TextEditingController();
  final _capacity = TextEditingController(text: '8');
  final _start = TextEditingController();
  final _end = TextEditingController();
  final _player = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _instructor.dispose();
    _capacity.dispose();
    _start.dispose();
    _end.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    String? error;
    var sessions = _sessions;
    try {
      final res = await Api().get('/courts/${widget.courtId}/coaching');
      sessions = coachingRows(res.data);
    } catch (caught) {
      error = Api.failureMessage(caught, fallback: 'Could not load classes.');
    }
    if (!mounted) return;
    setState(() {
      _error = error;
      if (error == null) _sessions = sessions;
      _loading = false;
    });
  }

  /// Date then time picker; writes the `YYYY-MM-DD HH:MM:00` form the API expects.
  Future<void> _pickWhen(TextEditingController field) async {
    final now = DateTime.now();
    final current = DateTime.tryParse(field.text) ?? DateTime.tryParse(_start.text) ?? now;
    final date = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      initialDate: current.isBefore(now) ? now : current,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(current));
    if (time == null) return;
    String two(int n) => n.toString().padLeft(2, '0');
    setState(() => field.text =
        '${date.year}-${two(date.month)}-${two(date.day)} ${two(time.hour)}:${two(time.minute)}:00');
  }

  Future<void> _create() async {
    final body = coachingBody(
      title: _title.text,
      instructor: _instructor.text,
      capacity: _capacity.text,
      start: _start.text,
      end: _end.text,
    );
    if (body == null) {
      context.toastError('Add a name, an instructor, a capacity, and a start before the end.');
      return;
    }
    setState(() => _acting = true);
    try {
      await Api().post('/courts/${widget.courtId}/coaching', data: body);
      _title.clear();
      _instructor.clear();
      await _load();
    } catch (caught) {
      if (mounted) {
        context.toastError(Api.failureMessage(caught, fallback: 'The class could not be saved.'));
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _enroll(int sessionId) async {
    final body = enrollmentBody(_player.text);
    if (body == null) {
      context.toastError('Add the player name.');
      return;
    }
    setState(() => _acting = true);
    try {
      await Api().post('/coaching-sessions/$sessionId/enrollments', data: body);
      _player.clear();
      await _load();
    } catch (caught) {
      if (mounted) {
        context.toastError(Api.failureMessage(caught, fallback: 'The player could not be added.'));
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _mark(int sessionId, int enrollmentId, String mark) async {
    final body = attendanceBody(mark);
    if (body == null) return;
    setState(() => _acting = true);
    try {
      await Api().post('/coaching-sessions/$sessionId/enrollments/$enrollmentId/attendance', data: body);
      await _load();
    } catch (caught) {
      if (mounted) {
        context.toastError(Api.failureMessage(caught, fallback: 'Attendance could not be saved.'));
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _cancel(int sessionId) async {
    setState(() => _acting = true);
    try {
      await Api().post('/coaching-sessions/$sessionId/cancel');
      await _load();
    } catch (caught) {
      if (mounted) {
        context.toastError(Api.failureMessage(caught, fallback: 'The class could not be cancelled.'));
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Coaching', style: TextStyle(fontWeight: FontWeight.w800))),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.primary,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  if (_error != null) TabErrorBanner(message: _error!, onRetry: _load),
                  TextField(controller: _title, decoration: const InputDecoration(labelText: 'Class name')),
                  TextField(controller: _instructor, decoration: const InputDecoration(labelText: 'Instructor')),
                  TextField(controller: _capacity, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Capacity')),
                  TextField(controller: _start, readOnly: true, onTap: () => _pickWhen(_start), decoration: const InputDecoration(labelText: 'Start date and time', suffixIcon: Icon(Icons.event))),
                  TextField(controller: _end, readOnly: true, onTap: () => _pickWhen(_end), decoration: const InputDecoration(labelText: 'End date and time', suffixIcon: Icon(Icons.event))),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton(
                      onPressed: _acting ? null : _create,
                      style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                      child: const Text('Add class'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Saving a class closes that court time.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: 20),
                  if (_error == null && _sessions.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 24),
                      child: TabEmptyMessage(
                        icon: AppIcons.users,
                        title: 'No classes yet',
                        subtitle: 'Add a class with an instructor and a capacity',
                      ),
                    ),
                  for (final session in _sessions) ...[
                    Text((session['title'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text(coachingLine(session)),
                    for (final player in (session['enrollments'] as List? ?? const []))
                      if (player is Map)
                        Row(
                          children: [
                          Expanded(
                            child: Text(
                              '${player['display_name']}${player['attendance'] == null ? '' : ' · ${player['attendance']}'}',
                            ),
                          ),
                            if (session['status'] == 'scheduled' && player['attendance'] == null) ...[
                              TextButton(onPressed: _acting ? null : () => _mark(_id(session), _id(player), 'present'), child: const Text('Present')),
                              TextButton(onPressed: _acting ? null : () => _mark(_id(session), _id(player), 'absent'), child: const Text('Absent')),
                            ],
                          ],
                        ),
                    if (session['status'] == 'scheduled') ...[
                      TextField(controller: _player, decoration: const InputDecoration(labelText: 'Player name')),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(onPressed: _acting ? null : () => _enroll(_id(session)), child: const Text('Add player')),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(onPressed: _acting ? null : () => _cancel(_id(session)), child: const Text('Cancel class')),
                      ),
                    ],
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
    );
  }

  int _id(Map row) => int.tryParse('${row['id']}') ?? 0;
}
