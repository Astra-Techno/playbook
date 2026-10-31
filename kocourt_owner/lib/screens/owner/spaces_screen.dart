import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kocourt_shared/kocourt_shared.dart';
import '../../widgets/tab_phase.dart';
import '../../widgets/tab_status.dart';
import 'space_detail_screen.dart';
import 'space_fields.dart';
import 'space_form_screen.dart';
import 'venue_listing.dart';

class SpacesScreen extends StatefulWidget {
  final int courtId;
  const SpacesScreen({super.key, required this.courtId});

  @override
  State<SpacesScreen> createState() => _SpacesScreenState();
}

class _SpacesScreenState extends State<SpacesScreen> {
  List<Map<String, dynamic>> _spaces = [];
  bool _loading = true;
  bool _canManage = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_spaces.isEmpty && mounted) {
      setState(() => _loading = true);
    }
    String? error;
    List<Map<String, dynamic>>? spaces;
    var canManage = false;
    final auth = context.read<AuthProvider>();
    try {
      final courtRes = await Api().get('/courts/${widget.courtId}');
      final raw = courtRes.data['court'];
      if (raw is Map) {
        canManage = venueOwnedBy(Map<String, dynamic>.from(raw), auth.userId);
      }
    } catch (_) {
      canManage = false;
    }
    try {
      final res = await Api().get('/sub-courts', params: {'court_id': widget.courtId});
      spaces = List<Map<String, dynamic>>.from(
        (res.data['sub_courts'] ?? []).map((e) => Map<String, dynamic>.from(e)),
      );
    } catch (caught) {
      error = Api.failureMessage(caught, fallback: 'Could not load spaces.');
    }
    if (!mounted) return;
    setState(() {
      if (spaces != null) _spaces = spaces;
      _canManage = canManage;
      _error = error;
      _loading = false;
    });
  }

  Future<void> _openForm({int? spaceId, Map<String, dynamic>? initial}) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => SpaceFormScreen(
          courtId: widget.courtId,
          spaceId: spaceId,
          initial: initial,
        ),
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _deleteSpace(Map<String, dynamic> space) async {
    final id = asSpaceId(space['id']);
    if (id == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete space?'),
        content: const Text(
          'This removes the space from the venue. Existing bookings stay on record. A space with an upcoming booking cannot be deleted.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await Api().delete('/sub-courts/$id');
      _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(Api.failureMessage(error, fallback: 'Could not delete this space.')),
        backgroundColor: AppColors.error,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Spaces', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          if (_canManage)
            IconButton(onPressed: () => _openForm(), icon: const Icon(AppIcons.plus)),
        ],
      ),
      body: _body(),
    );
  }

  Widget _body() {
    final phase = tabPhase(
      loading: _loading,
      failed: _error != null,
      hasData: _spaces.isNotEmpty,
    );
    if (phase == TabPhase.loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: phase == TabPhase.ready
          ? ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              itemCount: _spaces.length + (_error != null ? 1 : 0),
              itemBuilder: (_, i) {
                if (_error != null && i == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TabErrorBanner(message: _error!, onRetry: _load),
                  );
                }
                final offset = _error != null ? 1 : 0;
                return _spaceTile(_spaces[i - offset], i - offset);
              },
            )
          : ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                if (phase == TabPhase.failed)
                  TabErrorBanner(message: _error ?? 'Could not load spaces.', onRetry: _load)
                else
                  Padding(
                    padding: const EdgeInsets.only(top: 100),
                    child: Column(
                      children: [
                        const TabEmptyMessage(
                          icon: AppIcons.layoutGrid,
                          title: 'No spaces yet',
                          subtitle: 'Add courts, lanes, or rooms',
                        ),
                        if (_canManage) ...[
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => _openForm(),
                          icon: const Icon(AppIcons.plus, size: 16),
                          label: const Text('Add space'),
                        ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _spaceTile(Map<String, dynamic> space, int index) {
    final id = asSpaceId(space['id']);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: id == null
                  ? null
                  : () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => SpaceDetailScreen(courtId: widget.courtId, spaceId: id),
                      )).then((_) => _load()),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(child: Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(space['name'] ?? 'Space ${index + 1}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                          const SizedBox(height: 2),
                          Text(
                            spaceModeLabel(space['booking_mode'], space['capacity']),
                            style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_canManage)
            IconButton(
              onPressed: () => _deleteSpace(space),
              icon: Icon(Icons.delete_outline, size: 20, color: Colors.grey[400]),
            ),
        ],
      ),
    );
  }
}
