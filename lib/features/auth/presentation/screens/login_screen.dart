import 'package:dio/dio.dart';
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

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _showPass = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(loginProvider.notifier).login(
          _emailCtrl.text.trim(),
          _passCtrl.text,
        );
    if (mounted) {
      final state = ref.read(loginProvider);
      if (state is AsyncData) {
        context.go('/dashboard');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loginState = ref.watch(loginProvider);
    final error = loginState is AsyncError ? _parseError(loginState.error) : null;
    final loading = loginState is AsyncLoading;

    return AuthLayout(
      title: 'Selamat datang kembali',
      subtitle: 'Masuk untuk melanjutkan perjalanan habitmu',
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
              label: 'Email',
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              placeholder: 'email@contoh.com',
              autofocus: true,
              validator: (v) => v!.isEmpty ? 'Email wajib diisi' : null,
            ),
            const SizedBox(height: 14),
            HtInput(
              label: 'Password',
              controller: _passCtrl,
              obscureText: !_showPass,
              placeholder: '••••••••',
              validator: (v) => v!.isEmpty ? 'Password wajib diisi' : null,
              suffix: IconButton(
                icon: Icon(
                  _showPass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  size: 18,
                  color: AppColors.muted,
                ),
                onPressed: () => setState(() => _showPass = !_showPass),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () => context.push('/forgot-password'),
                child: Text(
                  'Lupa password?',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            HtButton(
              label: 'Masuk →',
              onPressed: _submit,
              loading: loading,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Belum punya akun? ',
                  style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.muted),
                ),
                GestureDetector(
                  onTap: () => context.go('/register'),
                  child: Text(
                    'Daftar sekarang',
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

  String _parseError(Object error) {
    if (error is DioException) {
      final status = error.response?.statusCode;
      final data = error.response?.data;
      if (status == 401 || status == 422) {
        // Coba ambil pesan dari backend
        if (data is Map) {
          final msg = data['message'] ?? data['error'];
          if (msg != null) return msg.toString();
        }
        return 'Email atau password salah.';
      }
      if (error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        return 'Tidak bisa terhubung ke server. Periksa koneksi internet.';
      }
      if (status != null) return 'Server error ($status). Coba lagi.';
    }
    return 'Terjadi kesalahan: ${error.toString()}';
  }
}
