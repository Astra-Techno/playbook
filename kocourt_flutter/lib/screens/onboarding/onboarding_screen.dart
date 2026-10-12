import 'package:flutter/material.dart';
import 'package:kocourt_shared/kocourt_shared.dart';
import '../login/login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageCtrl = PageController();
  int _page = 0;

  static const _pages = [
    {'icon': Icons.sports_tennis, 'title': 'Find Courts Near You', 'desc': 'Discover badminton, tennis, cricket, and more sports venues in your area.'},
    {'icon': Icons.calendar_month, 'title': 'Book Instantly', 'desc': 'Pick your time slot, pay online, and your booking is confirmed in seconds.'},
    {'icon': Icons.people, 'title': 'Play Together', 'desc': 'Find players, join matches, and build your sports community.'},
  ];

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
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Skip
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _goToLogin,
                child: Text('Skip', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey[500])),
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
                        Container(
                          width: 120, height: 120,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(p['icon'] as IconData, size: 56, color: AppColors.primary),
                        ),
                        const SizedBox(height: 40),
                        Text(p['title'] as String, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900), textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        Text(p['desc'] as String, style: TextStyle(fontSize: 15, color: Colors.grey[500], height: 1.5), textAlign: TextAlign.center),
                      ],
                    ),
                  );
                },
              ),
            ),
            // Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pages.length, (i) => Container(
                width: _page == i ? 24 : 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: _page == i ? Colors.black : Colors.grey[300],
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
                  child: Text(_page == _pages.length - 1 ? 'Get Started' : 'Next', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
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
