import 'package:flutter/material.dart';
import '../../core/api.dart';
import '../../core/icons.dart';
import '../../core/theme.dart';
import 'ledger_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<Map<String, dynamic>> _claims = [];
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final claimsRes = await Api().get('/courts/claims');
      _claims = List<Map<String, dynamic>>.from(
        (claimsRes.data['records'] ?? []).map((e) => Map<String, dynamic>.from(e)),
      );
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _handleClaim(int id, String action) async {
    try {
      await Api().put('/courts/claims/$id', data: {'status': action});
      _load();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Admin', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LedgerScreen())),
            icon: const Icon(Icons.receipt_long),
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: AppColors.primary,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          tabs: const [Tab(text: 'Claims'), Tab(text: 'Users')],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : TabBarView(
              controller: _tabCtrl,
              children: [_buildClaims(), _buildUsers()],
            ),
    );
  }

  Widget _buildClaims() {
    if (_claims.isEmpty) return Center(child: Text('No pending claims', style: TextStyle(color: Colors.grey[400])));
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _claims.length,
        itemBuilder: (_, i) {
          final c = _claims[i];
          final isPending = c['status'] == 'pending';
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c['venue_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 4),
                Text('Claimed by: ${c['user_name'] ?? c['phone'] ?? ''}', style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                Text('Phone: ${c['phone'] ?? ''}', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isPending ? Colors.orange.withValues(alpha: 0.1) : AppColors.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    (c['status'] ?? 'pending').toString().toUpperCase(),
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: isPending ? Colors.orange : AppColors.secondary),
                  ),
                ),
                if (isPending) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _handleClaim(c['id'], 'rejected'),
                          style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.error)),
                          child: const Text('Reject', style: TextStyle(color: AppColors.error)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _handleClaim(c['id'], 'approved'),
                          child: const Text('Approve'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildUsers() {
    return Center(child: Text('User management coming soon', style: TextStyle(color: Colors.grey[400])));
  }
}
