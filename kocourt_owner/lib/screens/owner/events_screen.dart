import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kocourt_shared/kocourt_shared.dart';
import '../../widgets/tab_phase.dart';
import '../../widgets/tab_status.dart';
import 'event_fields.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _events = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    String? error;
    var events = _events;
    try {
      final res = await Api().get('/tournaments');
      events = eventRows(res.data);
    } catch (caught) {
      error = Api.failureMessage(caught, fallback: 'Could not load events.');
    }
    if (!mounted) return;
    setState(() {
      _error = error;
      if (error == null) _events = events;
      _loading = false;
    });
  }

  Future<void> _create() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (_) => const _DraftSheet(),
    );
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final phase = tabPhase(loading: _loading, failed: _error != null, hasData: _events.isNotEmpty);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Events', style: TextStyle(fontWeight: FontWeight.w800))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New draft'),
      ),
      body: phase == TabPhase.loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.primary,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
                children: [
                  if (_error != null) ...[
                    TabErrorBanner(message: _error!, onRetry: _load),
                    const SizedBox(height: 16),
                  ],
                  if (phase == TabPhase.empty)
                    const Padding(
                      padding: EdgeInsets.only(top: 80),
                      child: TabEmptyMessage(
                        icon: AppIcons.calendarDays,
                        title: 'No events yet',
                        subtitle: 'Save a draft, then publish it when the venue time is free',
                      ),
                    )
                  else
                    for (final event in _events)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          (event['title'] ?? 'Event').toString(),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text('${event['sport'] ?? ''} · ${eventStatusLabel(event['status'])}'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push('/events/${event['id']}'),
                      ),
                ],
              ),
            ),
    );
  }
}

class _DraftSheet extends StatefulWidget {
  const _DraftSheet();

  @override
  State<_DraftSheet> createState() => _DraftSheetState();
}

class _DraftSheetState extends State<_DraftSheet> {
  final _title = TextEditingController();
  final _sport = TextEditingController();
  final _court = TextEditingController();
  final _start = TextEditingController();
  final _end = TextEditingController();
  final _sponsor = TextEditingController();
  String _visibility = 'private';
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _sport.dispose();
    _court.dispose();
    _start.dispose();
    _end.dispose();
    _sponsor.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final body = eventDraftBody(
      title: _title.text,
      sport: _sport.text,
      visibility: _visibility,
      courtId: _court.text,
      start: _start.text,
      end: _end.text,
      sponsor: _sponsor.text,
    );
    if (body == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a title and a sport. Times use YYYY-MM-DD HH:MM:SS.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await Api().post('/tournaments', data: body);
      if (mounted) Navigator.pop(context, true);
    } catch (caught) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(Api.failureMessage(caught, fallback: 'The draft could not be saved.'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('New draft', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title')),
          TextField(controller: _sport, decoration: const InputDecoration(labelText: 'Sport')),
          DropdownButtonFormField<String>(
            initialValue: _visibility,
            decoration: const InputDecoration(labelText: 'Visibility'),
            items: const [
              DropdownMenuItem(value: 'private', child: Text('Private')),
              DropdownMenuItem(value: 'public', child: Text('Public')),
            ],
            onChanged: (value) => setState(() => _visibility = value ?? 'private'),
          ),
          TextField(
            controller: _court,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Venue id, optional'),
          ),
          TextField(
            controller: _start,
            decoration: const InputDecoration(labelText: 'Start, optional', hintText: 'YYYY-MM-DD HH:MM:SS'),
          ),
          TextField(
            controller: _end,
            decoration: const InputDecoration(labelText: 'End, optional', hintText: 'YYYY-MM-DD HH:MM:SS'),
          ),
          TextField(controller: _sponsor, decoration: const InputDecoration(labelText: 'Sponsor, optional')),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            child: Text(_saving ? 'Saving' : 'Save draft'),
          ),
        ],
      ),
    );
  }
}
