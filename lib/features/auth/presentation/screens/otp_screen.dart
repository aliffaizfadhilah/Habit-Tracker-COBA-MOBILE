import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../widgets/auth_layout.dart';
import '../widgets/ht_button.dart';
import '../widgets/ht_alert.dart';

class OtpScreen extends StatefulWidget {
  final String email;
  final String mode; // 'register' | 'forgot'

  const OtpScreen({super.key, required this.email, required this.mode});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> _ctrls = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _foci = List.generate(6, (_) => FocusNode());
  bool _loading = false;
  String? _error;

  String get _otp => _ctrls.map((c) => c.text).join();

  @override
  void dispose() {
    for (final c in _ctrls) {
      c.dispose();
    }
    for (final f in _foci) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_otp.length < 6) {
      setState(() => _error = 'Masukkan 6 digit OTP');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      setState(() => _loading = false);
      if (widget.mode == 'register') {
        context.go('/login');
      } else {
        context.go('/reset-password',
            extra: {'email': widget.email, 'otp': _otp});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'Verifikasi OTP',
      subtitle: 'Masukkan 6 digit kode yang dikirim ke\n${widget.email}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            HtAlert(type: AlertType.error, message: _error!),
            const SizedBox(height: 16),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, (i) {
              return SizedBox(
                width: 46,
                height: 56,
                child: TextFormField(
                  controller: _ctrls[i],
                  focusNode: _foci[i],
                  textAlign: TextAlign.center,
                  style: GoogleFonts.syne(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(1),
                  ],
                  decoration: InputDecoration(
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border, width: 1.5),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border, width: 1.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary, width: 2),
                    ),
                    filled: true,
                    fillColor: AppColors.white,
                  ),
                  onChanged: (v) {
                    if (v.isNotEmpty && i < 5) {
                      _foci[i + 1].requestFocus();
                    }
                    if (v.isEmpty && i > 0) {
                      _foci[i - 1].requestFocus();
                    }
                    setState(() {});
                  },
                ),
              );
            }),
          ),
          const SizedBox(height: 24),
          HtButton(
            label: 'Verifikasi',
            onPressed: _submit,
            loading: _loading,
          ),
          const SizedBox(height: 16),
          Center(
            child: GestureDetector(
              onTap: () => context.pop(),
              child: Text(
                '← Kembali',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
