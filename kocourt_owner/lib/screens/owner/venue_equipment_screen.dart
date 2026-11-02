import 'package:flutter/material.dart';
import 'package:kocourt_shared/kocourt_shared.dart';
import '../../widgets/tab_status.dart';
import 'equipment_fields.dart';

class VenueEquipmentScreen extends StatefulWidget {
  final int courtId;
  const VenueEquipmentScreen({super.key, required this.courtId});

  @override
  State<VenueEquipmentScreen> createState() => _VenueEquipmentScreenState();
}

class _VenueEquipmentScreenState extends State<VenueEquipmentScreen> {
  bool _loading = true;
  bool _acting = false;
  String? _error;
  List<Map<String, dynamic>> _items = const [];
  final _name = TextEditingController();
  final _quantity = TextEditingController(text: '1');
  final _deposit = TextEditingController(text: '0');
  final _player = TextEditingController();
  final _rentQuantity = TextEditingController(text: '1');

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _quantity.dispose();
    _deposit.dispose();
    _player.dispose();
    _rentQuantity.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    String? error;
    var items = _items;
    try {
      final res = await Api().get('/courts/${widget.courtId}/equipment');
      items = equipmentRows(res.data);
    } catch (caught) {
      error = Api.failureMessage(caught, fallback: 'Could not load equipment.');
    }
    if (!mounted) return;
    setState(() {
      _error = error;
      if (error == null) _items = items;
      _loading = false;
    });
  }

  Future<void> _create() async {
    final body = equipmentBody(name: _name.text, quantity: _quantity.text, deposit: _deposit.text);
    if (body == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add a name, a quantity from 1 to 200, and a deposit.')));
      return;
    }
    setState(() => _acting = true);
    try {
      await Api().post('/courts/${widget.courtId}/equipment', data: body);
      _name.clear();
      await _load();
    } catch (caught) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(Api.failureMessage(caught, fallback: 'The item could not be saved.'))));
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _rent(int itemId) async {
    final body = rentalBody(_player.text, _rentQuantity.text);
    if (body == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add the player name and a quantity.')));
      return;
    }
    setState(() => _acting = true);
    try {
      await Api().post('/equipment/$itemId/rentals', data: body);
      _player.clear();
      await _load();
    } catch (caught) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(Api.failureMessage(caught, fallback: 'The rental could not be saved.'))));
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _return(int rentalId, String depositStatus) async {
    final body = returnBody(depositStatus);
    if (body == null) return;
    setState(() => _acting = true);
    try {
      await Api().post('/equipment-rentals/$rentalId/return', data: body);
      await _load();
    } catch (caught) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(Api.failureMessage(caught, fallback: 'The return could not be saved.'))));
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Equipment', style: TextStyle(fontWeight: FontWeight.w800))),
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
                  TextField(controller: _name, decoration: const InputDecoration(labelText: 'Item name')),
                  TextField(controller: _quantity, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity on hand')),
                  TextField(controller: _deposit, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Deposit, rupees')),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton(
                      onPressed: _acting ? null : _create,
                      style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                      child: const Text('Add item'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('A rental does not create a booking or a payment.', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                  const SizedBox(height: 20),
                  if (_error == null && _items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 24),
                      child: TabEmptyMessage(
                        icon: AppIcons.layoutGrid,
                        title: 'No equipment yet',
                        subtitle: 'Add an item with a quantity and a deposit',
                      ),
                    ),
                  for (final item in _items) ...[
                    Text((item['name'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text(equipmentLine(item)),
                    for (final rental in (item['rentals'] as List? ?? const []))
                      if (rental is Map)
                        Row(
                          children: [
                            Expanded(child: Text('${rental['display_name']} · ${rental['quantity']} · Deposit held')),
                            TextButton(onPressed: _acting ? null : () => _return(_id(rental), 'returned'), child: const Text('Return deposit')),
                            TextButton(onPressed: _acting ? null : () => _return(_id(rental), 'kept'), child: const Text('Keep deposit')),
                          ],
                        ),
                    if (item['status'] == 'active') ...[
                      TextField(controller: _player, decoration: const InputDecoration(labelText: 'Player name')),
                      TextField(controller: _rentQuantity, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity')),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(onPressed: _acting ? null : () => _rent(_id(item)), child: const Text('Rent out')),
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
