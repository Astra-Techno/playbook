import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kocourt_shared/kocourt_shared.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Same format the server prints on the player's pass (BookingCheckIn::payload).
const checkInPrefix = 'KOCOURT-CHECKIN';
final _codePattern = RegExp(r'^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{8}$');

/// Pass payload from a typed booking number and 8-character code, or null if either is wrong.
String? manualCheckInPayload(String bookingNumber, String code) {
  final id = int.tryParse(bookingNumber.replaceAll('#', '').trim());
  final clean = code.replaceAll(RegExp(r'\s'), '').toUpperCase();
  if (id == null || id <= 0 || !_codePattern.hasMatch(clean)) return null;
  return '$checkInPrefix:$id:$clean';
}

/// "2 – 3 PM" from two "YYYY-MM-DD HH:MM:SS" values.
String checkInTimeRange(Object? start, Object? end) {
  String clock(Object? raw, {bool suffix = true}) {
    final at = DateTime.tryParse('${raw ?? ''}');
    if (at == null) return '';
    final h12 = at.hour % 12 == 0 ? 12 : at.hour % 12;
    final mins = at.minute == 0 ? '' : ':${at.minute.toString().padLeft(2, '0')}';
    return '$h12$mins${suffix ? (at.hour < 12 ? ' AM' : ' PM') : ''}';
  }

  final a = clock(start);
  final b = clock(end);
  if (a.isEmpty || b.isEmpty) return a;
  return a.substring(a.length - 2) == b.substring(b.length - 2) ? '${clock(start, suffix: false)} – $b' : '$a – $b';
}

class _ScanResult {
  const _ScanResult({required this.ok, required this.message, this.booking});
  final bool ok;
  final String message;
  final Map<String, dynamic>? booking;
}

/// Front-desk QR scanner: point at a player's pass to check them in.
class ScanCheckInScreen extends StatefulWidget {
  const ScanCheckInScreen({super.key});

  @override
  State<ScanCheckInScreen> createState() => _ScanCheckInScreenState();
}

class _ScanCheckInScreenState extends State<ScanCheckInScreen> {
  final _camera = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );
  bool _busy = false;
  _ScanResult? _result;

  @override
  void dispose() {
    _camera.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    final raw = capture.barcodes.isEmpty ? null : capture.barcodes.first.rawValue;
    if (raw == null || _busy || _result != null) return;
    _submit(raw);
  }

  Future<void> _submit(String payload) async {
    setState(() => _busy = true);
    await _camera.stop();
    _ScanResult result;
    try {
      final res = await Api().post('/bookings/check-in-scan', data: {'payload': payload});
      final data = res.data is Map ? Map<String, dynamic>.from(res.data) : <String, dynamic>{};
      result = _ScanResult(
        ok: true,
        message: '${data['message'] ?? 'Checked in.'}',
        booking: data['booking'] is Map ? Map<String, dynamic>.from(data['booking']) : null,
      );
      HapticFeedback.heavyImpact();
    } catch (caught) {
      final body = caught is DioException ? caught.response?.data : null;
      result = _ScanResult(
        ok: false,
        message: Api.failureMessage(caught, fallback: 'Could not check this pass.'),
        booking: body is Map && body['booking'] is Map ? Map<String, dynamic>.from(body['booking']) : null,
      );
      HapticFeedback.vibrate();
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _result = result;
    });
  }

  Future<void> _scanNext() async {
    setState(() => _result = null);
    await _camera.start();
  }

  Future<void> _enterCode() async {
    final number = TextEditingController();
    final code = TextEditingController();
    final payload = await showDialog<String>(
      context: context,
      builder: (dialog) {
        String? problem;
        return StatefulBuilder(
          builder: (dialog, setDialog) => AlertDialog(
            title: const Text('Enter pass code'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: number,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Booking number', prefixText: '#'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: code,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(labelText: 'Check-in code (8 letters)', errorText: problem),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () {
                  final built = manualCheckInPayload(number.text, code.text);
                  if (built == null) {
                    setDialog(() => problem = 'Check the booking number and the 8-letter code.');
                    return;
                  }
                  Navigator.pop(dialog, built);
                },
                child: const Text('Check in'),
              ),
            ],
          ),
        );
      },
    );
    number.dispose();
    code.dispose();
    if (payload != null && mounted) _submit(payload);
  }

  @override
  Widget build(BuildContext context) {
    final brand = context.brand.primary;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _camera,
            onDetect: _onDetect,
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  error.errorCode == MobileScannerErrorCode.permissionDenied
                      ? 'Allow camera access in Settings to scan passes. You can still enter the code by hand.'
                      : 'The camera could not start. You can still enter the code by hand.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
              ),
            ),
          ),
          IgnorePointer(child: CustomPaint(painter: _FramePainter(brand))),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  _RoundButton(icon: Icons.close_rounded, label: 'Close', onTap: () => Navigator.of(context).maybePop()),
                  const Spacer(),
                  _RoundButton(icon: Icons.flashlight_on_rounded, label: 'Torch', onTap: () => _camera.toggleTorch()),
                ],
              ),
            ),
          ),
          Align(
            alignment: const Alignment(0, -0.62),
            child: Transform(
              transform: Matrix4.skewX(-0.17),
              alignment: Alignment.center,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(color: brand, borderRadius: BorderRadius.circular(8)),
                child: Text('SCAN BOOKING PASS', style: GoogleFonts.archivo(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1)),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 320),
                  switchInCurve: Curves.easeOutBack,
                  transitionBuilder: (child, animation) => SlideTransition(
                    position: Tween(begin: const Offset(0, 0.4), end: Offset.zero).animate(animation),
                    child: FadeTransition(opacity: animation, child: child),
                  ),
                  child: _result != null
                      ? _ResultCard(key: ValueKey(_result), result: _result!, onNext: _scanNext)
                      : _busy
                          ? const Padding(
                              key: ValueKey('busy'),
                              padding: EdgeInsets.all(24),
                              child: CircularProgressIndicator(color: Colors.white),
                            )
                          : Column(
                              key: const ValueKey('hint'),
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  "Point at the QR on the player's booking pass.",
                                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  onPressed: _enterCode,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: const BorderSide(color: Colors.white54),
                                  ),
                                  icon: const Icon(Icons.keyboard_rounded),
                                  label: const Text('Enter code instead'),
                                ),
                              ],
                            ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({super.key, required this.result, required this.onNext});
  final _ScanResult result;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final booking = result.booking;
    final colour = result.ok ? AppColors.secondary : AppColors.error;
    final where = [booking?['venue'], booking?['space']].where((v) => '${v ?? ''}'.isNotEmpty).join(' · ');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Transform(
                transform: Matrix4.skewX(-0.17),
                alignment: Alignment.center,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: colour, borderRadius: BorderRadius.circular(6)),
                  child: Text(result.ok ? 'CHECKED IN' : 'NOT CHECKED IN',
                      style: GoogleFonts.archivo(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.8)),
                ),
              ),
              const Spacer(),
              if (booking?['id'] != null) Text('#${booking!['id']}', style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          if (booking != null) ...[
            Text('${booking['player'] ?? 'Player'}', style: GoogleFonts.archivo(fontSize: 22, fontWeight: FontWeight.w900)),
            if (where.isNotEmpty || booking['start_time'] != null)
              Text(
                [where, checkInTimeRange(booking['start_time'], booking['end_time'])].where((s) => s.isNotEmpty).join(' · '),
                style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
              ),
            const SizedBox(height: 8),
          ],
          if (!result.ok || booking == null) Text(result.message, style: TextStyle(color: colour, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: onNext,
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const Text('Scan next pass'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black45,
      shape: const CircleBorder(),
      child: IconButton(tooltip: label, onPressed: onTap, icon: Icon(icon, color: Colors.white)),
    );
  }
}

/// Dimmed camera with a clear square and brand-coloured corner brackets.
class _FramePainter extends CustomPainter {
  const _FramePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.width * 0.68;
    final window = Rect.fromCenter(center: size.center(const Offset(0, -30)), width: side, height: side);
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Offset.zero & size),
        Path()..addRRect(RRect.fromRectAndRadius(window, const Radius.circular(24))),
      ),
      Paint()..color = Colors.black54,
    );
    final corner = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    const arm = 34.0;
    for (final (x, y, dx, dy) in [
      (window.left, window.top, 1.0, 1.0),
      (window.right, window.top, -1.0, 1.0),
      (window.left, window.bottom, 1.0, -1.0),
      (window.right, window.bottom, -1.0, -1.0),
    ]) {
      canvas.drawPath(
        Path()
          ..moveTo(x, y + dy * arm)
          ..lineTo(x, y)
          ..lineTo(x + dx * arm, y),
        corner,
      );
    }
  }

  @override
  bool shouldRepaint(_FramePainter oldDelegate) => oldDelegate.color != color;
}
