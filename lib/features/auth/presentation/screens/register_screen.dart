import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_layout.dart';
import '../widgets/ht_input.dart';
import '../widgets/ht_button.dart';
import '../widgets/ht_alert.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _showPass = false;
  bool _showConfirm = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(registerProvider.notifier).register(
          name: _nameCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text,
          passwordConfirmation: _confirmCtrl.text,
        );
    if (mounted) {
      final state = ref.read(registerProvider);
      if (state is AsyncData) {
        context.go('/otp-verify', extra: {'email': _emailCtrl.text.trim(), 'mode': 'register'});
      }
    }
  }

  int get _strength {
    final p = _passCtrl.text;
    int s = 0;
    if (p.length >= 8) s++;
    if (RegExp(r'[A-Z]').hasMatch(p)) s++;
    if (RegExp(r'[0-9]').hasMatch(p)) s++;
    if (RegExp(r'[!@#\$%^&*]').hasMatch(p)) s++;
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(registerProvider);
    final error = state is AsyncError ? 'Pendaftaran gagal. Periksa data kamu.' : null;
    final loading = state is AsyncLoading;

    return AuthLayout(
      title: 'Buat akun baru',
      subtitle: 'Mulai perjalanan membangun habit positifmu',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (error != null) ...[
              HtAlert(type: AlertType.error, message: error),
              const SizedBox(height: 16),
            ],
            HtInput(
              label: 'Nama lengkap',
              controller: _nameCtrl,
              placeholder: 'Nama kamu',
              autofocus: true,
              validator: (v) => v!.isEmpty ? 'Nama wajib diisi' : null,
            ),
            const SizedBox(height: 14),
            HtInput(
              label: 'Email',
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              placeholder: 'email@contoh.com',
              validator: (v) => v!.isEmpty ? 'Email wajib diisi' : null,
            ),
            const SizedBox(height: 14),
            HtInput(
              label: 'Password',
              controller: _passCtrl,
              obscureText: !_showPass,
              placeholder: 'Min. 8 karakter',
              onChanged: (_) => setState(() {}),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Password wajib diisi';
                if (v.length < 8) return 'Minimal 8 karakter';
                return null;
              },
              suffix: IconButton(
                icon: Icon(
                  _showPass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  size: 18,
                  color: AppColors.muted,
                ),
                onPressed: () => setState(() => _showPass = !_showPass),
              ),
            ),
            if (_passCtrl.text.isNotEmpty) ...[
              const SizedBox(height: 8),
              _PasswordStrengthBar(strength: _strength),
            ],
            const SizedBox(height: 14),
            HtInput(
              label: 'Konfirmasi password',
              controller: _confirmCtrl,
              obscureText: !_showConfirm,
              placeholder: 'Ulangi password',
              validator: (v) {
                if (v!.isEmpty) return 'Konfirmasi password wajib diisi';
                if (v != _passCtrl.text) return 'Password tidak cocok';
                return null;
              },
              suffix: IconButton(
                icon: Icon(
                  _showConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  size: 18,
                  color: AppColors.muted,
                ),
                onPressed: () => setState(() => _showConfirm = !_showConfirm),
              ),
            ),
            const SizedBox(height: 20),
            HtButton(
              label: 'Daftar →',
              onPressed: _submit,
              loading: loading,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Sudah punya akun? ',
                  style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.muted),
                ),
                GestureDetector(
                  onTap: () => context.go('/login'),
                  child: Text(
                    'Masuk sekarang',
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PasswordStrengthBar extends StatelessWidget {
  final int strength;
  const _PasswordStrengthBar({required this.strength});

  @override
  Widget build(BuildContext context) {
    final labels = ['Sangat lemah', 'Lemah', 'Cukup', 'Kuat'];
    final colors = [AppColors.error, AppColors.warning, AppColors.accent, AppColors.primary];
    final idx = (strength - 1).clamp(0, 3);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(4, (i) {
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                height: 3,
                decoration: BoxDecoration(
                  color: i < strength ? colors[idx] : AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 4),
        Text(
          strength > 0 ? labels[idx] : '',
          style: GoogleFonts.dmSans(
            fontSize: 11,
            color: strength > 0 ? colors[idx] : AppColors.subtle,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
