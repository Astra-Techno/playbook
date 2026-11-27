import 'package:flutter/material.dart';
import 'package:kocourt_shared/kocourt_shared.dart';
import '../login/login_screen.dart';
import '../home/widgets/day_strip.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageCtrl = PageController();
  int _page = 0;

  static const _pages = [
    {'title': 'Find courts near you', 'desc': 'Football, badminton, cricket, tennis and more, sorted by how close they are.'},
    {'title': 'See free hours at a glance', 'desc': 'Every venue shows its day. Pick an hour, pay, and your pass is ready.'},
    {'title': 'Play with your crew', 'desc': 'Add your squad, fill open spots from Matches, and rebook in one tap.'},
  ];

  /// Each slide previews the real feature it describes.
  Widget _visual(int i) {
    switch (i) {
      case 0:
        const sports = ['turf', 'shuttle', 'cricket', 'tennis', 'swimming', 'basket'];
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: [
            for (final sp in sports)
              Container(
                width: 72,
                height: 72,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [sportTint(sp).bg, Colors.white]),
                  border: Border.all(color: AppColors.border),
                ),
                child: SportIcon(sp, size: 36, tint: Colors.white),
              ),
          ],
        );
      case 1:
        return const KoCard(
          sport: 'turf',
          kicker: 'Free tonight',
          title: 'Kick Arena',
          meta: 'Football · 2.4 km',
          badge: '7 PM',
          middle: DayStrip(strip: 'ttfftftttftftfppt', tone: Color(0xFF047857), highlightHour: 19),
        );
      default:
        return const KoCard(
          kicker: 'Your squad',
          title: 'Tuesday 5s',
          meta: 'Kick Arena · Tue 7 PM',
          badge: '\u20B9240',
          middle: JerseyRow(names: ['Arjun K', 'Ravi', 'Sam', 'Priya'], open: 1, note: '1 spot open'),
        );
    }
  }

  void _next() {
    if (_page < _pages.length - 1) {
      _pageCtrl.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      _goToLogin();
    }
  }

  void _goToLogin() {
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Skip
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _goToLogin,
                child: Text('Skip', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
              ),
            ),
            // Pages
            Expanded(
              child: PageView.builder(
                controller: _pageCtrl,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) {
                  final p = _pages[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _visual(i),
                        const SizedBox(height: 40),
                        Text(p['title'] as String, style: AppFonts.display(fontSize: 26, height: 1.15), textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        Text(p['desc'] as String, style: TextStyle(fontSize: 15, color: AppColors.textSecondary, height: 1.5), textAlign: TextAlign.center),
                      ],
                    ),
                  );
                },
              ),
            ),
            // Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pages.length, (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: _page == i ? 24 : 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: _page == i ? AppColors.primary : AppColors.textDisabled,
                  borderRadius: BorderRadius.circular(4),
                ),
              )),
            ),
            const SizedBox(height: 32),
            // Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton(
                  onPressed: _next,
                  child: Text(_page == _pages.length - 1 ? 'Get started' : 'Next', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                ),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
          ],
        ),
      ),
    );
  }
}
