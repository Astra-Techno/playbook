import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kocourt_shared/kocourt_shared.dart';
import '../../widgets/tab_status.dart';
import 'event_fields.dart';

class EventDetailScreen extends StatefulWidget {
  final int tournamentId;

  const EventDetailScreen({super.key, required this.tournamentId});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _event;
  List<Map<String, dynamic>> _categories = const [];
  List<Map<String, dynamic>> _announcements = const [];
  bool _acting = false;

  final _name = TextEditingController();
  final _fee = TextEditingController();
  final _capacity = TextEditingController();
  final _door = TextEditingController();
  final _announceTitle = TextEditingController();
  final _announceBody = TextEditingController();
  String _format = 'singles';
  bool _waitlist = false;
  bool _approval = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _fee.dispose();
    _capacity.dispose();
    _door.dispose();
    _announceTitle.dispose();
    _announceBody.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    String? error;
    Map<String, dynamic>? event = _event;
    var categories = _categories;
    var announcements = _announcements;
    try {
      final list = await Api().get('/tournaments');
      event = null;
      for (final row in eventRows(list.data)) {
        if (int.tryParse('${row['id']}') == widget.tournamentId) {
          event = row;
          break;
        }
      }
      if (event == null) {
        error = 'Event not found';
      } else {
        final cats = await Api().get('/tournaments/${widget.tournamentId}/categories');
        categories = categoryRows(cats.data);
        for (final category in categories) {
          final categoryId = int.tryParse('${category['id']}') ?? 0;
          if (categoryId <= 0) {
            category['entries'] = <Map<String, dynamic>>[];
            continue;
          }
          final entries = await Api().get('/tournaments/${widget.tournamentId}/categories/$categoryId/registrations');
          category['entries'] = registrationRows(entries.data);
          final matches = await Api().get('/tournaments/${widget.tournamentId}/categories/$categoryId/matches');
          category['matches'] = matchRows(matches.data);
          category['champion_registration_id'] = bracketChampion(matches.data);
        }
        final notes = await Api().get('/tournaments/${widget.tournamentId}/announcements');
        announcements = announcementRows(notes.data);
      }
    } catch (caught) {
      error = Api.failureMessage(caught, fallback: 'Could not load this event.');
    }
    if (!mounted) return;
    setState(() {
      _error = error;
      if (error == null) {
        _event = event;
        _categories = categories;
        _announcements = announcements;
      }
      _loading = false;
    });
  }

  Future<void> _export() async {
    if (_acting) return;
    setState(() => _acting = true);
    try {
      final res = await Api().get('/tournaments/${widget.tournamentId}/export');
      final body = res.data is String ? res.data as String : '';
      if (!participantCsv(body)) {
        throw const FormatException('The export was not a participant file.');
      }
      await Clipboard.setData(ClipboardData(text: body));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Participants copied.')));
    } catch (caught) {
      if (!mounted) return;
      final message = caught is FormatException
          ? caught.message
          : Api.failureMessage(caught, fallback: 'Could not export participants.');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _checkInCode() async {
    final body = checkInCodeBody(_door.text);
    if (body == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the 8-character entry code.')),
      );
      return;
    }
    if (_acting) return;
    setState(() => _acting = true);
    try {
      final res = await Api().post('/tournaments/${widget.tournamentId}/check-in', data: body);
      if (!mounted) return;
      final message = res.data is Map ? (res.data['message'] ?? 'Checked in.').toString() : 'Checked in.';
      _door.clear();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      await _load();
    } catch (caught) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(Api.failureMessage(caught, fallback: 'This entry could not be checked in.'))),
      );
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _review(int categoryId, int registrationId, String action) async {
    if (_acting) return;
    setState(() => _acting = true);
    try {
      final res = await Api().post('/tournaments/${widget.tournamentId}/categories/$categoryId/registrations/$registrationId/$action');
      if (!mounted) return;
      final message = res.data is Map ? (res.data['message'] ?? 'Saved.').toString() : 'Saved.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      await _load();
    } catch (caught) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(Api.failureMessage(caught, fallback: 'This entry could not be reviewed.'))),
      );
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _checkIn(int categoryId, int registrationId) async {
    if (_acting) return;
    setState(() => _acting = true);
    try {
      final res = await Api().post('/tournaments/${widget.tournamentId}/categories/$categoryId/registrations/$registrationId/check-in');
      if (!mounted) return;
      final message = res.data is Map ? (res.data['message'] ?? 'Checked in.').toString() : 'Checked in.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      await _load();
    } catch (caught) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(Api.failureMessage(caught, fallback: 'This entry could not be checked in.'))),
      );
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _status() async {
    final action = eventAction(_event?['status']);
    if (action == null || _acting) return;
    setState(() => _acting = true);
    try {
      final res = await Api().post('/tournaments/${widget.tournamentId}/$action');
      if (!mounted) return;
      final message = res.data is Map ? (res.data['message'] ?? 'Saved.').toString() : 'Saved.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      await _load();
    } catch (caught) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(Api.failureMessage(caught, fallback: 'The event could not be updated.'))),
      );
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _announce() async {
    final body = announcementBody(title: _announceTitle.text, body: _announceBody.text);
    if (body == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a title and a message. Keep the message within 500 characters.')),
      );
      return;
    }
    if (_acting) return;
    setState(() => _acting = true);
    try {
      final res = await Api().post('/tournaments/${widget.tournamentId}/announcements', data: body);
      if (!mounted) return;
      final message = res.data is Map ? (res.data['message'] ?? 'Announcement sent.').toString() : 'Announcement sent.';
      _announceTitle.clear();
      _announceBody.clear();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      await _load();
    } catch (caught) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(Api.failureMessage(caught, fallback: 'The announcement could not be sent.'))),
      );
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _addMatch(Map<String, dynamic> category) async {
    final confirmed = [
      for (final entry in (category['entries'] as List? ?? const []))
        if (entry is Map && entry['state'] == 'confirmed') Map<String, dynamic>.from(entry),
    ];
    if (confirmed.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A match needs two confirmed entries')));
      return;
    }
    var home = int.tryParse('${confirmed.first['id']}') ?? 0;
    var away = int.tryParse('${confirmed[1]['id']}') ?? 0;
    final picked = await showDialog<Map<String, int>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('Add match', style: TextStyle(fontWeight: FontWeight.w800)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: home,
                items: [
                  for (final entry in confirmed)
                    DropdownMenuItem(value: int.tryParse('${entry['id']}') ?? 0, child: Text(registrationLine(entry))),
                ],
                onChanged: (value) => setDialog(() => home = value ?? home),
              ),
              DropdownButtonFormField<int>(
                initialValue: away,
                items: [
                  for (final entry in confirmed)
                    DropdownMenuItem(value: int.tryParse('${entry['id']}') ?? 0, child: Text(registrationLine(entry))),
                ],
                onChanged: (value) => setDialog(() => away = value ?? away),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, {'home': home, 'away': away}), child: const Text('Add')),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    final body = matchBody(homeId: picked['home'] ?? 0, awayId: picked['away'] ?? 0);
    if (body == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A match needs two different entries')));
      return;
    }
    final categoryId = int.tryParse('${category['id']}') ?? 0;
    setState(() => _acting = true);
    try {
      await Api().post('/tournaments/${widget.tournamentId}/categories/$categoryId/matches', data: body);
      await _load();
    } catch (caught) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(Api.failureMessage(caught, fallback: 'The match could not be added.'))));
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _buildBracket(Map<String, dynamic> category) async {
    final categoryId = int.tryParse('${category['id']}') ?? 0;
    setState(() => _acting = true);
    try {
      await Api().post('/tournaments/${widget.tournamentId}/categories/$categoryId/bracket');
      await _load();
    } catch (caught) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(Api.failureMessage(caught, fallback: 'The bracket could not be saved.'))));
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _recordResult(Map<String, dynamic> category, Map<String, dynamic> match) async {
    final homeScore = TextEditingController();
    final awayScore = TextEditingController();
    final picked = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Score', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: homeScore, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Home score')),
            TextField(controller: awayScore, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Away score')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, {'home': homeScore.text, 'away': awayScore.text}),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (picked == null || !mounted) return;
    final body = resultBody(
      homeId: int.tryParse('${match['home_registration_id']}') ?? 0,
      awayId: int.tryParse('${match['away_registration_id']}') ?? 0,
      homeScore: picked['home'] ?? '',
      awayScore: picked['away'] ?? '',
    );
    if (body == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A winner needs a higher score')));
      return;
    }
    final categoryId = int.tryParse('${category['id']}') ?? 0;
    final matchId = int.tryParse('${match['id']}') ?? 0;
    setState(() => _acting = true);
    try {
      await Api().post('/tournaments/${widget.tournamentId}/categories/$categoryId/matches/$matchId/result', data: body);
      await _load();
    } catch (caught) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(Api.failureMessage(caught, fallback: 'The score could not be saved.'))));
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _addCategory() async {
    final body = categoryBody(
      name: _name.text,
      format: _format,
      fee: _fee.text,
      capacity: _capacity.text,
      waitlist: _waitlist,
      approval: _approval,
    );
    if (body == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a category name. Fee and capacity must be zero or more.')),
      );
      return;
    }
    setState(() => _acting = true);
    try {
      await Api().post('/tournaments/${widget.tournamentId}/categories', data: body);
      _name.clear();
      _fee.clear();
      _capacity.clear();
      await _load();
    } catch (caught) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(Api.failureMessage(caught, fallback: 'The category could not be saved.'))),
      );
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Widget _entryRow(Map<String, dynamic> category, Map<String, dynamic> entry) {
    final categoryId = int.tryParse('${category['id']}') ?? 0;
    final entryId = int.tryParse('${entry['id']}') ?? 0;
    return Row(
      children: [
        Expanded(child: Text(registrationLine(entry))),
        if (registrationCanCheckIn(entry) && categoryId > 0 && entryId > 0)
          TextButton(
            onPressed: _acting ? null : () => _checkIn(categoryId, entryId),
            child: const Text('Check in'),
          ),
        if (entry['state']?.toString() == 'pending_approval' && categoryId > 0 && entryId > 0) ...[
          TextButton(
            onPressed: _acting ? null : () => _review(categoryId, entryId, 'approve'),
            child: const Text('Approve'),
          ),
          TextButton(
            onPressed: _acting ? null : () => _review(categoryId, entryId, 'reject'),
            child: const Text('Reject'),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final event = _event;
    final action = eventAction(event?['status']);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: Text((event?['title'] ?? 'Event').toString(), style: const TextStyle(fontWeight: FontWeight.w800))),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (_error != null) TabErrorBanner(message: _error!, onRetry: _load),
                if (event != null) ...[
                  Text(eventStatusLabel(event['status']), style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary)),
                  const SizedBox(height: 8),
                  Text((event['sport'] ?? '').toString()),
                  if ((event['start_time'] ?? '').toString().isNotEmpty)
                    Text('${event['start_time']} – ${event['end_time'] ?? ''}'),
                  const SizedBox(height: 16),
                  OutlinedButton(onPressed: _acting ? null : _export, child: const Text('Copy participants')),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _door,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(labelText: 'Entry code'),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(onPressed: _acting ? null : _checkInCode, child: const Text('Check in code')),
                  ),
                  if (action == 'publish')
                    FilledButton(
                      onPressed: _acting ? null : _status,
                      style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                      child: const Text('Publish'),
                    ),
                  if (action == 'unpublish')
                    OutlinedButton(onPressed: _acting ? null : _status, child: const Text('Unpublish')),
                  const SizedBox(height: 24),
                  const Text('Categories', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  if (_categories.isEmpty)
                    Text('No categories yet', style: TextStyle(color: Colors.grey[600]))
                  else
                    for (final category in _categories)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text((category['name'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
                            Text('${category['format'] ?? 'singles'} · fee ${category['fee'] ?? 0} · seats ${category['capacity'] ?? 0}'),
                            const SizedBox(height: 4),
                            if (category['entries'] is! List || (category['entries'] as List).isEmpty)
                              Text('No entries yet', style: TextStyle(color: Colors.grey[600]))
                            else
                              for (final entry in category['entries'] as List)
                                if (entry is Map) _entryRow(category, Map<String, dynamic>.from(entry)),
                            const SizedBox(height: 4),
                            if (bracketChampion({'champion_registration_id': category['champion_registration_id']}) != null)
                              Text(championLine(bracketChampion({'champion_registration_id': category['champion_registration_id']})!)),
                            if (category['matches'] is List && (category['matches'] as List).isNotEmpty)
                              for (final match in category['matches'] as List)
                                if (match is Map)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Row(
                                      children: [
                                        Expanded(child: Text(matchLine(Map<String, dynamic>.from(match)))),
                                        if (match['status'] == 'scheduled')
                                          TextButton(
                                            onPressed: _acting ? null : () => _recordResult(category, Map<String, dynamic>.from(match)),
                                            child: const Text('Score'),
                                          ),
                                      ],
                                    ),
                                  ),
                            if (category['matches'] is! List || (category['matches'] as List).isEmpty)
                              TextButton(
                                onPressed: _acting ? null : () => _buildBracket(category),
                                child: const Text('Build bracket'),
                              ),
                            TextButton(
                              onPressed: _acting ? null : () => _addMatch(category),
                              child: const Text('Add match'),
                            ),
                          ],
                        ),
                      ),
                  if (event['status'] == 'draft') ...[
                    const SizedBox(height: 12),
                    TextField(controller: _name, decoration: const InputDecoration(labelText: 'Category name')),
                    DropdownButtonFormField<String>(
                      initialValue: _format,
                      decoration: const InputDecoration(labelText: 'Format'),
                      items: const [
                        DropdownMenuItem(value: 'singles', child: Text('Singles')),
                        DropdownMenuItem(value: 'doubles', child: Text('Doubles')),
                        DropdownMenuItem(value: 'team', child: Text('Team')),
                      ],
                      onChanged: (value) => setState(() => _format = value ?? 'singles'),
                    ),
                    TextField(controller: _fee, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Fee, optional')),
                    TextField(controller: _capacity, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Capacity, optional')),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Waitlist when full'),
                      value: _waitlist,
                      activeThumbColor: AppColors.primary,
                      onChanged: (value) => setState(() => _waitlist = value),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Organizer approves entries'),
                      value: _approval,
                      activeThumbColor: AppColors.primary,
                      onChanged: (value) => setState(() => _approval = value),
                    ),
                    FilledButton(
                      onPressed: _acting ? null : _addCategory,
                      style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                      child: const Text('Add category'),
                    ),
                  ],
                  const SizedBox(height: 24),
                  const Text('Announcements', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  if (_announcements.isEmpty)
                    Text('No announcements yet', style: TextStyle(color: Colors.grey[600]))
                  else
                    for (final note in _announcements)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text((note['title'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
                            Text((note['body'] ?? '').toString()),
                          ],
                        ),
                      ),
                  TextField(controller: _announceTitle, decoration: const InputDecoration(labelText: 'Announcement title')),
                  TextField(
                    controller: _announceBody,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Message'),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(onPressed: _acting ? null : _announce, child: const Text('Send announcement')),
                  ),
                ],
              ],
            ),
    );
  }
}
