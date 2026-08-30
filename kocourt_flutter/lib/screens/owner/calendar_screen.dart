import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/api.dart';
import '../../core/icons.dart';
import '../../core/theme.dart';

class CalendarScreen extends StatefulWidget {
  final int courtId;
  const CalendarScreen({super.key, required this.courtId});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _bookings = [];
  Set<int> _busyDays = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMonth();
    _loadDay();
  }

  Future<void> _loadMonth() async {
    try {
      final month = DateFormat('yyyy-MM').format(_selectedDate);
      final res = await Api().get('/bookings/busy-days', params: {'court_id': widget.courtId, 'month': month});
      _busyDays = Set<int>.from((res.data['days'] ?? []).map((d) => int.tryParse('$d') ?? 0));
    } catch (_) {}
    if (mounted) setState(() {});
  }

  Future<void> _loadDay() async {
    setState(() => _loading = true);
    try {
      final date = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final res = await Api().get('/bookings', params: {'court_id': widget.courtId, 'date': date});
      _bookings = List<Map<String, dynamic>>.from(
        (res.data['records'] ?? []).map((e) => Map<String, dynamic>.from(e)),
      );
    } catch (_) {}
    setState(() => _loading = false);
  }

  void _changeDate(DateTime date) {
    final monthChanged = date.month != _selectedDate.month || date.year != _selectedDate.year;
    setState(() => _selectedDate = date);
    if (monthChanged) _loadMonth();
    _loadDay();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final firstOfMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
    final daysInMonth = DateTime(_selectedDate.year, _selectedDate.month + 1, 0).day;
    final startWeekday = firstOfMonth.weekday % 7; // Sun=0

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Calendar', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Column(
        children: [
          // Month nav
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () => _changeDate(DateTime(_selectedDate.year, _selectedDate.month - 1, 1)),
                  icon: const Icon(AppIcons.chevronLeft, size: 20),
                ),
                Text(DateFormat('MMMM yyyy').format(_selectedDate), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                IconButton(
                  onPressed: () => _changeDate(DateTime(_selectedDate.year, _selectedDate.month + 1, 1)),
                  icon: const Icon(AppIcons.chevronRight, size: 20),
                ),
              ],
            ),
          ),
          // Weekday headers
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                  .map((d) => Expanded(child: Center(child: Text(d, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey[400])))))
                  .toList(),
            ),
          ),
          const SizedBox(height: 4),
          // Calendar grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7),
              itemCount: startWeekday + daysInMonth,
              itemBuilder: (_, i) {
                if (i < startWeekday) return const SizedBox();
                final day = i - startWeekday + 1;
                final isSelected = day == _selectedDate.day;
                final isBusy = _busyDays.contains(day);
                final isToday = day == now.day && _selectedDate.month == now.month && _selectedDate.year == now.year;
                return GestureDetector(
                  onTap: () => _changeDate(DateTime(_selectedDate.year, _selectedDate.month, day)),
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.black : null,
                      borderRadius: BorderRadius.circular(10),
                      border: isToday && !isSelected ? Border.all(color: AppColors.primary) : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('$day', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isSelected ? Colors.white : Colors.black)),
                        if (isBusy)
                          Container(
                            width: 5, height: 5, margin: const EdgeInsets.only(top: 2),
                            decoration: BoxDecoration(color: isSelected ? Colors.white : AppColors.primary, shape: BoxShape.circle),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 24),
          // Day bookings
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(DateFormat('EEE, MMM d').format(_selectedDate), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                const Spacer(),
                Text('${_bookings.length} bookings', style: TextStyle(fontSize: 13, color: Colors.grey[400])),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _bookings.isEmpty
                    ? Center(child: Text('No bookings', style: TextStyle(color: Colors.grey[400])))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: _bookings.length,
                        itemBuilder: (_, i) {
                          final b = _bookings[i];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12)),
                            child: Row(
                              children: [
                                Container(
                                  width: 4, height: 40,
                                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(b['user_name'] ?? 'Player', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                      Text('${b['start_time'] ?? ''} - ${b['end_time'] ?? ''}',
                                          style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                                      if (b['sub_court_name'] != null)
                                        Text(b['sub_court_name'], style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                                    ],
                                  ),
                                ),
                                Text('₹${b['amount'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary)),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
