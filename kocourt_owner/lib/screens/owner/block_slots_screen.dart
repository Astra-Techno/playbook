import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kocourt_shared/kocourt_shared.dart';
import '../../widgets/tab_phase.dart';
import '../../widgets/tab_status.dart';
import 'schedule_fields.dart';

class BlockSlotsScreen extends StatefulWidget {
  final int courtId;
  final int? spaceId;
  const BlockSlotsScreen({super.key, required this.courtId, this.spaceId});

  @override
  State<BlockSlotsScreen> createState() => _BlockSlotsScreenState();
}

class _BlockSlotsScreenState extends State<BlockSlotsScreen> {
  List<Map<String, dynamic>> _blocked = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    String? error;
    List<Map<String, dynamic>>? blocks;
    try {
      final res = await Api().get('/blocked-slots', params: {
        'court_id': widget.courtId,
        if (widget.spaceId != null) 'sub_court_id': widget.spaceId,
      });
      final raw = res.data['blocks'];
      if (raw is! List) throw const FormatException('Missing blocks');
      blocks = raw.map((row) => Map<String, dynamic>.from(row as Map)).toList();
    } catch (caught) {
      error = Api.failureMessage(caught, fallback: 'Could not load closures.');
    }
    if (!mounted) return;
    setState(() {
      if (blocks != null) _blocked = blocks;
      _error = error;
      _loading = false;
    });
  }

  Future<void> _addBlock() async {
    var start = DateTime.now().add(const Duration(hours: 1));
    var end = start.add(const Duration(hours: 2));
    final reasonCtrl = TextEditingController();
    var kind = 'maintenance';
    var repeat = false;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Close a time', style: TextStyle(fontWeight: FontWeight.w800)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.spaceId == null
                      ? 'This closes every space. Bookings already on the calendar stay until they are cancelled.'
                      : 'This closes this space. A whole-venue closure still applies here. Existing bookings stay.',
                  style: const TextStyle(fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: 12),
                _whenTile(ctx, 'Starts', start, (value) => setDialogState(() => start = value)),
                _whenTile(ctx, 'Ends', end, (value) => setDialogState(() => end = value)),
                const SizedBox(height: 8),
                TextField(controller: reasonCtrl, decoration: const InputDecoration(hintText: 'Reason (optional)')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: kind,
                  items: [
                    for (final item in blockKinds)
                      DropdownMenuItem(value: item, child: Text(blockKindLabel(item))),
                  ],
                  onChanged: (value) => setDialogState(() => kind = value ?? 'other'),
                  decoration: const InputDecoration(labelText: 'Kind'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Repeat every year'),
                  value: repeat,
                  onChanged: (value) => setDialogState(() => repeat = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(
              onPressed: () async {
                try {
                  final body = blockRangeBody(
                    courtId: widget.courtId,
                    spaceId: widget.spaceId,
                    start: start,
                    end: end,
                    reason: reasonCtrl.text,
                    blockKind: kind,
                    repeatAnnually: repeat,
                  );
                  await Api().post('/blocked-slots', data: body);
                  if (ctx.mounted) Navigator.pop(ctx, true);
                } catch (caught) {
                  if (!ctx.mounted) return;
                  final message = caught is ScheduleFieldError
                      ? caught.message
                      : Api.failureMessage(caught, fallback: 'Could not close this time.');
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(message), backgroundColor: AppColors.error));
                }
              },
              child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.error)),
            ),
          ],
        ),
      ),
    );
    if (saved == true) _load();
  }

  Widget _whenTile(BuildContext ctx, String label, DateTime value, ValueChanged<DateTime> onChanged) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(DateFormat('d MMM yyyy, HH:mm').format(value)),
      onTap: () async {
        final date = await showDatePicker(
          context: ctx,
          firstDate: DateTime.now().subtract(const Duration(days: 1)),
          lastDate: DateTime.now().add(const Duration(days: 365)),
          initialDate: value,
        );
        if (date == null || !ctx.mounted) return;
        final time = await showTimePicker(context: ctx, initialTime: TimeOfDay.fromDateTime(value));
        if (time == null) return;
        onChanged(DateTime(date.year, date.month, date.day, time.hour, time.minute));
      },
    );
  }

  Future<void> _removeBlock(int id) async {
    try {
      await Api().delete('/blocked-slots/$id');
      _load();
    } catch (caught) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(Api.failureMessage(caught, fallback: 'Could not remove this closure.')),
        backgroundColor: AppColors.error,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final phase = tabPhase(loading: _loading, failed: _error != null, hasData: _blocked.isNotEmpty);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Closures', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [IconButton(onPressed: _addBlock, icon: const Icon(AppIcons.plus))],
      ),
      body: phase == TabPhase.loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : phase == TabPhase.failed
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: TabErrorBanner(message: _error!, onRetry: _load)))
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primary,
                  child: phase == TabPhase.empty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(20),
                          children: const [
                            TabEmptyMessage(
                              icon: Icons.block,
                              title: 'No closures',
                              subtitle: 'Closed times are hidden from new bookings.',
                            ),
                          ],
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(20),
                          itemCount: _blocked.length + (_error != null ? 1 : 0),
                          itemBuilder: (_, index) {
                            if (_error != null && index == 0) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: TabErrorBanner(message: _error!, onRetry: _load),
                              );
                            }
                            final block = _blocked[index - (_error != null ? 1 : 0)];
                            return _tile(block);
                          },
                        ),
                ),
    );
  }

  Widget _tile(Map<String, dynamic> block) {
    final id = asScheduleId(block['id']);
    final scope = block['sub_court_id'] == null ? 'Whole venue' : 'This space';
    final repeat = block['repeat_annually'] == 1 || block['repeat_annually'] == '1';
    final kind = blockKindLabel('${block['block_kind'] ?? 'other'}');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.block, size: 18, color: AppColors.error),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${block['start_time']} → ${block['end_time']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                Text(
                  '$scope · $kind${repeat ? ' · every year' : ''}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                if ('${block['reason'] ?? ''}'.isNotEmpty)
                  Text('${block['reason']}', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              ],
            ),
          ),
          if (id != null)
            IconButton(
              onPressed: () => _removeBlock(id),
              icon: Icon(Icons.close, size: 18, color: Colors.grey[400]),
            ),
        ],
      ),
    );
  }
}
