import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/auth_repository.dart';
import '../widgets/auth_layout.dart';
import '../widgets/ht_input.dart';
import '../widgets/ht_button.dart';
import '../widgets/ht_alert.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _sent = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Email wajib diisi');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).forgotPassword(email);
      setState(() => _sent = true);
    } catch (_) {
      setState(() => _error = 'Gagal mengirim kode OTP. Cek email kamu.');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'Lupa password?',
      subtitle: 'Masukkan emailmu dan kami akan kirimkan kode OTP',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            HtAlert(type: AlertType.error, message: _error!),
            const SizedBox(height: 16),
          ],
          if (_sent) ...[
            HtAlert(
              type: AlertType.success,
              message: 'Kode OTP telah dikirim ke ${_emailCtrl.text.trim()}',
            ),
            const SizedBox(height: 20),
            HtButton(
              label: 'Masukkan OTP →',
              onPressed: () => context.push(
                '/otp-verify',
                extra: {'email': _emailCtrl.text.trim(), 'mode': 'forgot'},
              ),
            ),
          ] else ...[
            HtInput(
              label: 'Email',
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              placeholder: 'email@contoh.com',
              autofocus: true,
            ),
            const SizedBox(height: 20),
            HtButton(
              label: 'Kirim kode OTP →',
              onPressed: _submit,
              loading: _loading,
            ),
          ],
          const SizedBox(height: 16),
          Center(
            child: GestureDetector(
              onTap: () => context.go('/login'),
              child: Text(
                '← Kembali ke login',
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
