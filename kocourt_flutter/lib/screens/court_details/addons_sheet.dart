import 'package:flutter/material.dart';
import 'package:kocourt_shared/kocourt_shared.dart';

/// Checkout payload lines for the chosen add-ons (zero counts dropped).
List<Map<String, int>> addonsPayload(Map<int, int> counts) => [
      for (final e in counts.entries)
        if (e.value > 0) {'item_id': e.key, 'quantity': e.value},
    ];

/// Estimated rental total in rupees; the server quote is the real price.
int addonsTotal(List<Map<String, dynamic>> addons, Map<int, int> counts) {
  var total = 0;
  for (final a in addons) {
    total += (counts[a['id']] ?? 0) * ((a['rental_rupees'] as num?)?.toInt() ?? 0);
  }
  return total;
}

/// "Add kit?" before paying. Returns the chosen counts, or null if dismissed.
class AddonsSheet extends StatefulWidget {
  const AddonsSheet({super.key, required this.addons});

  final List<Map<String, dynamic>> addons;

  static Future<Map<int, int>?> open(BuildContext context, List<Map<String, dynamic>> addons) {
    return showModalBottomSheet<Map<int, int>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddonsSheet(addons: addons),
    );
  }

  @override
  State<AddonsSheet> createState() => _AddonsSheetState();
}

class _AddonsSheetState extends State<AddonsSheet> {
  final _counts = <int, int>{};

  @override
  Widget build(BuildContext context) {
    final total = addonsTotal(widget.addons, _counts);
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Add kit?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          const Text('Rent from the venue. Paid now with your slot; any deposit is taken at the counter.',
              style: TextStyle(fontSize: 12, height: 1.4, color: AppColors.textMuted)),
          const SizedBox(height: 12),
          for (final a in widget.addons) _row(a),
          const SizedBox(height: 16),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, Map<int, int>.from(_counts)),
              child: Text(total > 0 ? 'Continue · +₹$total' : 'Continue without kit',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(Map<String, dynamic> a) {
    final id = (a['id'] as num).toInt();
    final count = _counts[id] ?? 0;
    final deposit = (a['deposit_rupees'] as num?)?.toInt() ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${a['name']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                Text(
                  '₹${a['rental_rupees']} each${deposit > 0 ? ' · ₹$deposit deposit at venue' : ''}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove one ${a['name']}',
            onPressed: count == 0 ? null : () => setState(() => _counts[id] = count - 1),
            icon: const Icon(Icons.remove_circle_outline),
          ),
          SizedBox(width: 24, child: Text('$count', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800))),
          IconButton(
            tooltip: 'Add one ${a['name']}',
            onPressed: count >= 20 ? null : () => setState(() => _counts[id] = count + 1),
            icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}
