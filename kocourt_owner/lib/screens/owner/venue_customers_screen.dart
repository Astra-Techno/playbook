import 'package:flutter/material.dart';
import 'package:kocourt_shared/kocourt_shared.dart';
import '../../widgets/tab_status.dart';
import 'customer_fields.dart';

class VenueCustomersScreen extends StatefulWidget {
  final int courtId;
  const VenueCustomersScreen({super.key, required this.courtId});

  @override
  State<VenueCustomersScreen> createState() => _VenueCustomersScreenState();
}

class _VenueCustomersScreenState extends State<VenueCustomersScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _customers = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    String? error;
    var customers = _customers;
    try {
      final res = await Api().get('/courts/${widget.courtId}/customers');
      customers = customerRows(res.data);
    } catch (caught) {
      error = Api.failureMessage(caught, fallback: 'Could not load customers.');
    }
    if (!mounted) return;
    setState(() {
      _error = error;
      if (error == null) _customers = customers;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Customers', style: TextStyle(fontWeight: FontWeight.w800))),
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
                  if (_error == null && _customers.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 80),
                      child: TabEmptyMessage(
                        icon: AppIcons.users,
                        title: 'No customers yet',
                        subtitle: 'Confirmed bookings at this venue show up here',
                      ),
                    ),
                  for (final customer in _customers)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text((customer['name'] ?? 'Player').toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text(customerLine(customer)),
                    ),
                ],
              ),
            ),
    );
  }
}
