import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/auth_repository.dart';
import '../widgets/auth_layout.dart';
import '../widgets/ht_input.dart';
import '../widgets/ht_button.dart';
import '../widgets/ht_alert.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  final String email;
  final String otp;

  const ResetPasswordScreen({super.key, required this.email, required this.otp});

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _showPass = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_passCtrl.text.isEmpty || _passCtrl.text.length < 8) {
      setState(() => _error = 'Password minimal 8 karakter');
      return;
    }
    if (_passCtrl.text != _confirmCtrl.text) {
      setState(() => _error = 'Password tidak cocok');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).resetPassword(
            email: widget.email,
            otp: widget.otp,
            password: _passCtrl.text,
            passwordConfirmation: _confirmCtrl.text,
          );
      if (mounted) context.go('/login');
    } catch (_) {
      setState(() => _error = 'Gagal reset password. Coba lagi.');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'Reset password',
      subtitle: 'Buat password baru untuk akunmu',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            HtAlert(type: AlertType.error, message: _error!),
            const SizedBox(height: 16),
          ],
          HtInput(
            label: 'Password baru',
            controller: _passCtrl,
            obscureText: !_showPass,
            placeholder: 'Min. 8 karakter',
            autofocus: true,
            suffix: IconButton(
              icon: Icon(
                _showPass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: 18,
              ),
              onPressed: () => setState(() => _showPass = !_showPass),
            ),
          ),
          const SizedBox(height: 14),
          HtInput(
            label: 'Konfirmasi password',
            controller: _confirmCtrl,
            obscureText: !_showPass,
            placeholder: 'Ulangi password baru',
          ),
          const SizedBox(height: 20),
          HtButton(
            label: 'Simpan password →',
            onPressed: _submit,
            loading: _loading,
          ),
        ],
      ),
    );
  }
}
