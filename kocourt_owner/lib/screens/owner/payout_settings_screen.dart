import 'package:flutter/material.dart';
import 'package:kocourt_shared/kocourt_shared.dart';

class PayoutSettingsScreen extends StatefulWidget {
  const PayoutSettingsScreen({super.key});

  @override
  State<PayoutSettingsScreen> createState() => _PayoutSettingsScreenState();
}

class _PayoutSettingsScreenState extends State<PayoutSettingsScreen> {
  bool _loading = true;
  bool _saving = false;
  String _accountType = 'bank_account'; // 'bank_account' or 'upi'
  double _commission = 10;
  String? _cfStatus;

  final _holderCtrl  = TextEditingController();
  final _accountCtrl = TextEditingController();
  final _ifscCtrl    = TextEditingController();
  final _upiCtrl     = TextEditingController();
  final _panCtrl     = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _holderCtrl.dispose();
    _accountCtrl.dispose();
    _ifscCtrl.dispose();
    _upiCtrl.dispose();
    _panCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await Api().get('/vendor/profile');
      final profile = res.data['profile'];
      _commission = (res.data['commission'] ?? 10).toDouble();

      if (profile != null) {
        _accountType = profile['account_type'] ?? 'bank_account';
        _holderCtrl.text = profile['account_holder'] ?? '';
        _ifscCtrl.text = profile['ifsc_code'] ?? '';
        _upiCtrl.text = profile['upi_vpa'] ?? '';
        _panCtrl.text = profile['pan_masked'] ?? '';
        _cfStatus = profile['cf_vendor_status'];
        // account_number is masked from API
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    // Validate
    if (_accountType == 'bank_account') {
      if (_holderCtrl.text.trim().isEmpty || _accountCtrl.text.trim().isEmpty || _ifscCtrl.text.trim().isEmpty) {
        _showError('Please fill account holder, account number, and IFSC code');
        return;
      }
    } else {
      if (_upiCtrl.text.trim().isEmpty) {
        _showError('Please enter your UPI VPA');
        return;
      }
    }

    setState(() => _saving = true);
    try {
      final res = await Api().post('/vendor/profile', data: {
        'account_type': _accountType,
        'account_holder': _holderCtrl.text.trim(),
        'account_number': _accountCtrl.text.trim(),
        'ifsc_code': _ifscCtrl.text.trim(),
        'upi_vpa': _upiCtrl.text.trim(),
        'pan_number': _panCtrl.text.trim(),
      });

      final status = res.data['cf_status'] ?? 'pending';
      if (mounted) {
        setState(() => _cfStatus = status);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(status == 'active' ? 'Payout account verified!' : 'Details saved. Verification pending.'),
            backgroundColor: status == 'active' ? AppColors.secondary : Colors.orange,
          ),
        );
      }
    } catch (e) {
      _showError('Failed to save. Please try again.');
    }
    if (mounted) setState(() => _saving = false);
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Payout Settings', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status badge
                  if (_cfStatus != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: _cfStatus == 'active'
                            ? AppColors.secondary.withValues(alpha: 0.08)
                            : Colors.orange.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _cfStatus == 'active' ? AppColors.secondary.withValues(alpha: 0.3) : Colors.orange.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _cfStatus == 'active' ? Icons.check_circle_rounded : Icons.schedule_rounded,
                            color: _cfStatus == 'active' ? AppColors.secondary : Colors.orange,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _cfStatus == 'active'
                                  ? 'Payout account verified. You\'ll receive ${(100 - _commission).toStringAsFixed(0)}% of each booking.'
                                  : 'Verification pending. Payouts will start once verified.',
                              style: TextStyle(
                                fontSize: 13,
                                color: _cfStatus == 'active' ? AppColors.secondary : Colors.orange[800],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Commission info
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded, color: Colors.grey[500], size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Platform fee: ${_commission.toStringAsFixed(0)}% · You receive: ${(100 - _commission).toStringAsFixed(0)}% per booking',
                            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Account type toggle
                  const Text('Payout Method', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _accountType = 'bank_account'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: _accountType == 'bank_account' ? AppColors.primary.withValues(alpha: 0.1) : Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _accountType == 'bank_account' ? AppColors.primary : Colors.grey[200]!,
                                width: _accountType == 'bank_account' ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(Icons.account_balance_rounded,
                                    color: _accountType == 'bank_account' ? AppColors.primary : Colors.grey[400], size: 28),
                                const SizedBox(height: 6),
                                Text('Bank Account',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                      color: _accountType == 'bank_account' ? AppColors.primary : Colors.grey[500],
                                    )),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _accountType = 'upi'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: _accountType == 'upi' ? AppColors.primary.withValues(alpha: 0.1) : Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _accountType == 'upi' ? AppColors.primary : Colors.grey[200]!,
                                width: _accountType == 'upi' ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(Icons.currency_rupee_rounded,
                                    color: _accountType == 'upi' ? AppColors.primary : Colors.grey[400], size: 28),
                                const SizedBox(height: 6),
                                Text('UPI',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                      color: _accountType == 'upi' ? AppColors.primary : Colors.grey[500],
                                    )),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Account holder name (always shown)
                  _buildField('Account Holder Name', _holderCtrl, 'Full name as per bank/UPI'),

                  // Bank fields
                  if (_accountType == 'bank_account') ...[
                    _buildField('Account Number', _accountCtrl, 'Enter account number', keyboard: TextInputType.number),
                    _buildField('IFSC Code', _ifscCtrl, 'e.g. SBIN0001234'),
                  ],

                  // UPI field
                  if (_accountType == 'upi')
                    _buildField('UPI VPA', _upiCtrl, 'e.g. yourname@upi'),

                  // PAN (optional)
                  _buildField('PAN Number (optional)', _panCtrl, 'For tax purposes'),

                  const SizedBox(height: 32),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: _saving
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Save & Verify', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, String hint, {TextInputType? keyboard}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          TextField(
            controller: ctrl,
            keyboardType: keyboard,
            decoration: InputDecoration(
              hintText: hint,
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}
