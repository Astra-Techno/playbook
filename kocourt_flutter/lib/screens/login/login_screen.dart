import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:kocourt_shared/kocourt_shared.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  int _step = 1;
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  final _otpControllers = List.generate(4, (_) => TextEditingController());
  final _otpFocusNodes = List.generate(4, (_) => FocusNode());
  String? _error;
  // Resend cooldown so the code isn't requested again and again.
  int _resendIn = 0;
  Timer? _resendTimer;

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _resendIn = 30);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _resendIn <= 1) {
        t.cancel();
        if (mounted) setState(() => _resendIn = 0);
        return;
      }
      setState(() => _resendIn--);
    });
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _phoneController.dispose();
    _nameController.dispose();
    for (final c in _otpControllers) c.dispose();
    for (final f in _otpFocusNodes) f.dispose();
    super.dispose();
  }

  String get _otpString => _otpControllers.map((c) => c.text).join();

  Future<void> _sendOtp() async {
    setState(() => _error = null);
    final phone = _phoneController.text.trim();
    if (!RegExp(r'^\d{10}$').hasMatch(phone)) {
      setState(() => _error = 'Enter your 10-digit mobile number');
      return;
    }
    final auth = context.read<AuthProvider>();
    final err = await auth.sendOtp(phone);
    if (err != null) {
      setState(() => _error = err);
    } else {
      setState(() => _step = 2);
      _startResendTimer();
      Future.delayed(const Duration(milliseconds: 100), () {
        _otpFocusNodes[0].requestFocus();
      });
    }
  }

  Future<void> _verifyOtp() async {
    setState(() => _error = null);
    if (_otpString.length < 4) {
      setState(() => _error = 'Enter the 4-digit OTP');
      return;
    }
    final auth = context.read<AuthProvider>();
    final name = _step == 3 ? _nameController.text.trim() : null;
    if (_step == 3 && (name == null || name.isEmpty)) {
      setState(() => _error = 'Enter your name');
      return;
    }

    final result = await auth.verifyOtp(
      _phoneController.text.trim(),
      _otpString,
      name: name,
    );

    if (result['new_user'] == true) {
      setState(() => _step = 3);
    } else if (result['success'] == true) {
      if (mounted) context.go('/');
    } else {
      setState(() => _error = result['error'] ?? 'Something went wrong');
    }
  }

  void _goBack() {
    setState(() {
      _error = null;
      if (_step > 1) {
        _step--;
      } else {
        context.pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_step == 1) _buildStep1(),
              if (_step == 2) _buildStep2(),
              if (_step == 3) _buildStep3(),
            ],
          ),
        ),
      ),
    );
  }

  /// Matchday light header: soft violet into white, the real logo, a small
  /// violet kicker and the step title in the display font.
  Widget _buildBrandHeader({
    required String subtitle,
    required String title,
    Widget? leading,
    String? description,
  }) {
    final brand = context.brand.primary;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color.alphaBlend(brand.withValues(alpha: 0.10), Colors.white), AppColors.surface],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 16, left: 20, right: 20, bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (leading != null) ...[leading, const SizedBox(width: 12)],
              if (leading == null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.asset('assets/images/logo.png', width: 44, height: 44, fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(width: 44, height: 44, color: brand)),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('KoCourt', style: AppFonts.display(fontSize: 19, color: AppColors.textPrimary)),
                    const Text('Book courts. Find players.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ],
            ],
          ),
          const SizedBox(height: 28),
          Text(subtitle.toUpperCase(), style: AppFonts.score(fontSize: 13, letterSpacing: 1.4, color: brand)),
          const SizedBox(height: 6),
          Text(title, style: AppFonts.display(fontSize: 28, height: 1.15, color: AppColors.textPrimary)),
          if (description != null) ...[
            const SizedBox(height: 6),
            Text(description, style: const TextStyle(fontSize: 15, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildBrandHeader(
          subtitle: 'Get started',
          title: 'Enter your mobile\nnumber',
        ),

        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) _buildError(),
              const SizedBox(height: 4),
              Text('Mobile number', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                        border: Border(
                          right: BorderSide(color: AppColors.border),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Text('\u{1F1EE}\u{1F1F3}', style: TextStyle(fontSize: 16)),
                          const SizedBox(width: 6),
                          Text(
                            '+91',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Semantics(
                        identifier: 'phone_input',
                        child: TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                        ),
                        decoration: InputDecoration(
                          hintText: '98765 43210',
                          hintStyle: TextStyle(
                            color: AppColors.textDisabled,
                            fontWeight: FontWeight.normal,
                            fontSize: 18,
                            letterSpacing: 0,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                        onSubmitted: (_) => _sendOtp(),
                      ),
                    ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Consumer<AuthProvider>(
                builder: (context, auth, _) => _buildPrimaryButton(
                  onPressed: _sendOtp,
                  isLoading: auth.isLoading,
                  label: 'Continue',
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('By continuing you agree to our ', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  GestureDetector(
                    onTap: () => context.push('/terms'),
                    child: const Text('Terms', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary, decoration: TextDecoration.underline)),
                  ),
                  Text(' and ', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  GestureDetector(
                    onTap: () => context.push('/privacy'),
                    child: const Text('Privacy Policy', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary, decoration: TextDecoration.underline)),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final c in sportCategories.where((c) => c.id != 'All'))
                    Container(
                      padding: const EdgeInsets.fromLTRB(8, 5, 12, 5),
                      decoration: BoxDecoration(color: sportTint(c.id).bg, borderRadius: BorderRadius.circular(AppRadius.full)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        SportIcon(c.id, size: 16, tint: Colors.white),
                        const SizedBox(width: 5),
                        Text(c.label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: sportTint(c.id).fg)),
                      ]),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildBrandHeader(
          subtitle: 'Verify',
          title: 'Check your messages',
          description: '+91 ${_phoneController.text}',
          leading: _backButton(),
        ),

        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) _buildError(),
              const SizedBox(height: 8),
              Text('Enter the 4-digit code we sent', textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              AppOtpRow(
                controllers: _otpControllers,
                focusNodes: _otpFocusNodes,
                length: 4,
                onCompleted: (_) => _verifyOtp(),
              ),
              const SizedBox(height: 28),
              Consumer<AuthProvider>(
                builder: (context, auth, _) => _buildPrimaryButton(
                  onPressed: _verifyOtp,
                  isLoading: auth.isLoading,
                  label: 'Verify and continue',
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Didn't receive the OTP? ",
                    style: TextStyle(fontSize: 14, color: AppColors.textMuted),
                  ),
                  GestureDetector(
                    onTap: _resendIn > 0
                        ? null
                        : () async {
                            setState(() => _error = null);
                            for (final c in _otpControllers) {
                              c.clear();
                            }
                            _startResendTimer();
                            await context.read<AuthProvider>().sendOtp(_phoneController.text.trim());
                          },
                    child: Text(
                      _resendIn > 0 ? 'Resend in ${_resendIn}s' : 'Resend',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _resendIn > 0 ? AppColors.textMuted : AppColors.primary),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildBrandHeader(
          subtitle: 'New account',
          title: 'What should we\ncall you?',
          leading: _backButton(),
        ),

        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) _buildError(),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  children: [
                    const Text('\u{1F44B}', style: TextStyle(fontSize: 24)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
                          children: [
                            const TextSpan(text: 'Welcome! Signing up with\n'),
                            TextSpan(
                              text: '+91 ${_phoneController.text}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text('Your name', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Semantics(
                identifier: 'name_input',
                child: TextField(
                controller: _nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'e.g. Mathavan Kumar',
                  hintStyle: TextStyle(
                    color: AppColors.textDisabled,
                    fontWeight: FontWeight.normal,
                    fontSize: 16,
                  ),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: const BorderSide(color: AppColors.border, width: 2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: const BorderSide(color: AppColors.primary, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                onSubmitted: (_) => _verifyOtp(),
              ),
              ),
              const SizedBox(height: 20),
              Consumer<AuthProvider>(
                builder: (context, auth, _) => _buildPrimaryButton(
                  onPressed: _verifyOtp,
                  isLoading: auth.isLoading,
                  label: 'Create Account',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _backButton() {
    return GestureDetector(
      onTap: _goBack,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
      ),
    );
  }

  Widget _buildError() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.errorLight,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(
                color: AppColors.error,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryButton({
    required VoidCallback onPressed,
    required bool isLoading,
    required String label,
  }) {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          elevation: 0,
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ),
      ),
    );
  }
}
