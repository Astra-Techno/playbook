import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kocourt_shared/kocourt_shared.dart';
import '../../widgets/tab_status.dart';
import '../../widgets/sheets/walkin_sheet.dart';
import 'walk_in_fields.dart';
import 'booking_detail_screen.dart';

class CalendarScreen extends StatefulWidget {
  final int courtId;
  const CalendarScreen({super.key, required this.courtId});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _bookings = [];
  List<Map<String, dynamic>> _blocks = [];
  List<Map<String, dynamic>> _spaces = [];
  Set<int> _busyDays = {};
  bool _loading = true;
  bool _week = false;
  List<String> _weekDates = [];
  String? _dayError;
  String? _monthError;

  @override
  void initState() {
    super.initState();
    _loadMonth();
    _loadDay();
  }

  Future<void> _loadMonth() async {
    String? error;
    Set<int>? days;
    try {
      final month = DateFormat('yyyy-MM').format(_selectedDate);
      final res = await Api().get('/bookings/busy-days', params: {'court_id': widget.courtId, 'month': month});
      days = busyDayNumbers(res.data);
    } catch (caught) {
      error = Api.failureMessage(caught, fallback: 'Could not load this month.');
    }
    if (!mounted) return;
    setState(() {
      if (days != null) _busyDays = days;
      _monthError = error;
    });
  }

  Future<void> _loadDay() async {
    String? error;
    List<Map<String, dynamic>>? bookings;
    List<Map<String, dynamic>>? blocks;
    List<Map<String, dynamic>>? spaces;
    try {
      final date = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final res = await Api().get('/courts/${widget.courtId}/calendar', params: {
        'date': date,
        'view': _week ? 'week' : 'day',
      });
      final rawBookings = res.data['bookings'];
      final rawBlocks = res.data['blocked_slots'];
      final rawSpaces = res.data['sub_courts'];
      final rawDates = res.data['dates'];
      if (rawBookings is! List || rawBlocks is! List) {
        throw const FormatException('Missing day');
      }
      bookings = rawBookings.map((row) => Map<String, dynamic>.from(row as Map)).toList();
      blocks = rawBlocks.map((row) => Map<String, dynamic>.from(row as Map)).toList();
      spaces = rawSpaces is List
          ? rawSpaces.map((row) => Map<String, dynamic>.from(row as Map)).toList()
          : <Map<String, dynamic>>[];
      _weekDates = rawDates is List ? rawDates.map((day) => '$day').toList() : <String>[];
    } catch (caught) {
      error = Api.failureMessage(caught, fallback: 'Could not load this day.');
    }
    if (!mounted) return;
    setState(() {
      if (bookings != null) _bookings = bookings;
      if (blocks != null) _blocks = blocks;
      if (spaces != null) _spaces = spaces;
      _dayError = error;
      _loading = false;
    });
  }

  void _changeDate(DateTime date) {
    final monthChanged = date.month != _selectedDate.month || date.year != _selectedDate.year;
    setState(() {
      _selectedDate = date;
      _loading = true;
    });
    if (monthChanged) _loadMonth();
    _loadDay();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final firstOfMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
    final daysInMonth = DateTime(_selectedDate.year, _selectedDate.month + 1, 0).day;
    final startWeekday = firstOfMonth.weekday % 7;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Calendar', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => _week = !_week);
              _loadDay();
            },
            child: Text(_week ? 'Day' : 'Week'),
          ),
          TextButton(onPressed: _walkIn, child: const Text('Add booking')),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () => _week
                      ? _changeDate(_selectedDate.subtract(const Duration(days: 7)))
                      : _changeDate(DateTime(_selectedDate.year, _selectedDate.month - 1, 1)),
                  icon: const Icon(AppIcons.chevronLeft, size: 20),
                ),
                Text(
                  _week ? 'Week of ${DateFormat('d MMM').format(_selectedDate)}' : DateFormat('MMMM yyyy').format(_selectedDate),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                IconButton(
                  onPressed: () => _week
                      ? _changeDate(_selectedDate.add(const Duration(days: 7)))
                      : _changeDate(DateTime(_selectedDate.year, _selectedDate.month + 1, 1)),
                  icon: const Icon(AppIcons.chevronRight, size: 20),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                  .map((d) => Expanded(child: Center(child: Text(d, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMuted)))))
                  .toList(),
            ),
          ),
          if (_monthError != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: TabErrorBanner(message: _monthError!, onRetry: _loadMonth),
            ),
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
                      color: isSelected ? context.brand.primary : null,
                      borderRadius: BorderRadius.circular(10),
                      border: isToday && !isSelected ? Border.all(color: AppColors.primary) : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('$day', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isSelected ? Colors.white : AppColors.textPrimary)),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(DateFormat('EEE, MMM d').format(_selectedDate), style: AppFonts.display(fontSize: 17, fontWeight: FontWeight.w900)),
                const Spacer(),
                Text('${_bookings.length} bookings', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _week
                    ? _weekList()
                    : _dayError != null && _bookings.isEmpty && _blocks.isEmpty
                    ? Center(child: Padding(padding: const EdgeInsets.all(24), child: TabErrorBanner(message: _dayError!, onRetry: _loadDay)))
                    : _bookings.isEmpty && _blocks.isEmpty
                        ? Center(child: Text('No bookings', style: TextStyle(color: AppColors.textMuted)))
                        : ListView(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            children: [
                              if (_dayError != null) ...[
                                TabErrorBanner(message: _dayError!, onRetry: _loadDay),
                                const SizedBox(height: 8),
                              ],
                              ..._blocks.map(_blockTile),
                              ..._bookings.map(_bookingTile),
                            ],
                          ),
          ),
        ],
      ),
    );
  }

  Future<void> _walkIn() async {
    final saved = await WalkInSheet.open(
      context,
      courtId: widget.courtId,
      date: DateFormat('yyyy-MM-dd').format(_selectedDate),
      spaces: _spaces,
    );
    if (saved) {
      _loadDay();
      _loadMonth();
    }
  }

  Widget _weekList() {
    final dates = _weekDates;
    if (_dayError != null && dates.isEmpty) {
      return Center(child: Padding(padding: const EdgeInsets.all(24), child: TabErrorBanner(message: _dayError!, onRetry: _loadDay)));
    }
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        if (_dayError != null) ...[
          TabErrorBanner(message: _dayError!, onRetry: _loadDay),
          const SizedBox(height: 8),
        ],
        for (final day in dates)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(day, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('${rowsOnDate(_bookings, day)} bookings · ${rowsOnDate(_blocks, day, annual: true)} closed'),
            onTap: () {
              final parts = day.split('-');
              if (parts.length != 3) return;
              setState(() => _week = false);
              _changeDate(DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2])));
            },
          ),
      ],
    );
  }

  Widget _bookingTile(Map<String, dynamic> booking) {
    final space = '${booking['sub_court_name'] ?? booking['space_name'] ?? ''}'.trim();
    final id = int.tryParse('${booking['id']}');
    return InkWell(
      onTap: id == null
          ? null
          : () async {
              final changed = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => BookingDetailScreen(bookingId: id)),
              );
              if (changed == true) {
                _loadDay();
                _loadMonth();
              }
            },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            TimePlate(
              top: _clock(booking['start_time'], hourOnly: true),
              bottom: 'to ${_clock(booking['end_time'])}',
              filled: booking['status'] != 'cancelled',
              width: 72,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(bookingPerson(booking), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                  if (space.isNotEmpty) Text(space, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  if (recordedAfterPlayLabel(booking) != null)
                    Text(recordedAfterPlayLabel(booking)!, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (booking['status'] == 'cancelled') StatusTag.forBooking('cancelled'),
                      if (booking['attendance'] == 'checked_in') const StatusTag('Checked in', tone: TagTone.free),
                      if (booking['attendance'] == 'no_show') const StatusTag('No-show', tone: TagTone.due),
                      if (booking['collection_method'] == 'pay_at_venue' && booking['payment_status'] != 'paid')
                        const StatusTag('Pay at venue', tone: TagTone.ending),
                    ],
                  ),
                ],
              ),
            ),
            Text(rupees(booking['total_price'] ?? 0), style: AppFonts.score(fontWeight: FontWeight.w900, fontSize: 15)),
          ],
        ),
      ),
    );
  }

  /// "6 PM" (hourOnly) or "7:30 PM" from "YYYY-MM-DD HH:MM:SS".
  String _clock(Object? raw, {bool hourOnly = false}) {
    final at = DateTime.tryParse('${raw ?? ''}');
    if (at == null) return '${raw ?? ''}';
    return DateFormat(hourOnly && at.minute == 0 ? 'h a' : 'h:mm a').format(at);
  }

  Widget _blockTile(Map<String, dynamic> block) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceDim,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const StatusTag('Closed', tone: TagTone.muted),
          const SizedBox(height: 6),
          Text('${_clock(block['start_time'])} – ${_clock(block['end_time'])}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          if ('${block['reason'] ?? ''}'.isNotEmpty)
            Text('${block['reason']}', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
