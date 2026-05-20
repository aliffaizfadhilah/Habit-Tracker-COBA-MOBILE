import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../post/domain/post_model.dart';
import '../../../post/presentation/screens/post_detail_screen.dart';
import '../../data/profile_repository.dart';
import '../../domain/profile_model.dart';
import '../providers/profile_provider.dart';

// ─── ProfileScreen ─────────────────────────────────────────────────────────────
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nameCtrl     = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _emailCtrl    = TextEditingController();
  bool _formInitialized = false;
  bool _saving = false;
  String? _saveError;
  String? _saveSuccess;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  void _initForm(UserProfile p) {
    if (_formInitialized) return;
    _nameCtrl.text     = p.fullName;
    _usernameCtrl.text = p.username;
    _emailCtrl.text    = p.email;
    _formInitialized   = true;
  }

  Future<void> _saveProfile() async {
    setState(() { _saving = true; _saveError = null; _saveSuccess = null; });
    try {
      await ref.read(profileRepositoryProvider).updateProfile(
        fullName: _nameCtrl.text.trim(),
        username: _usernameCtrl.text.trim(),
        email:    _emailCtrl.text.trim(),
      );
      ref.invalidate(profileProvider);
      _formInitialized = false;
      if (mounted) setState(() => _saveSuccess = 'Profil berhasil diperbarui!');
    } on DioException catch (e) {
      final data = e.response?.data;
      String msg = 'Terjadi kesalahan. Coba lagi.';
      if (data is Map) {
        final errs = data['errors'] as Map?;
        if (errs != null && errs.isNotEmpty) {
          final v = errs.values.first;
          msg = (v is List ? v.first : v).toString();
        } else if (data['message'] != null) {
          msg = data['message'].toString();
        }
      }
      if (mounted) setState(() => _saveError = msg);
    } catch (_) {
      if (mounted) setState(() => _saveError = 'Terjadi kesalahan. Coba lagi.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _openPasswordDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ChangePasswordDialog(
        onSuccess: () async {
          await ref.read(logoutProvider)();
          if (ctx.mounted) ctx.go('/login');
        },
      ),
    );
  }

  void _openLightbox(Post post) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)),
    ).then((deleted) {
      if (deleted == true) ref.invalidate(myPostsProvider);
    });
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Keluar?', style: GoogleFonts.syne(fontWeight: FontWeight.w700)),
        content: Text('Kamu akan keluar dari akunmu.', style: GoogleFonts.dmSans()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(logoutProvider)();
              if (ctx.mounted) ctx.go('/login');
            },
            child: const Text('Keluar', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);
    final postsAsync   = ref.watch(myPostsProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Profil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, size: 22),
            tooltip: 'Keluar',
            onPressed: _confirmLogout,
          ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const LoadingWidget(),
        error: (_, __) => ErrorWidget2(
          message: 'Gagal memuat profil',
          onRetry: () => ref.invalidate(profileProvider),
        ),
        data: (profile) {
          _initForm(profile);
          final posts         = postsAsync.valueOrNull ?? [];
          final isPostLoading = postsAsync.isLoading;
          final totalLikes    = posts.fold<int>(0, (s, p) => s + p.likesCount);
          final totalComments = posts.fold<int>(0, (s, p) => s + p.commentsCount);

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Card: Avatar + Stats ──────────────────────────────────
                _Card(child: Column(children: [
                  Row(children: [
                    _Avatar(profile: profile),
                    const SizedBox(width: 16),
                    Expanded(child: _NameBlock(profile: profile)),
                  ]),
                  const SizedBox(height: 16),
                  const Divider(height: 1, color: AppColors.border),
                  const SizedBox(height: 16),
                  Row(children: [
                    _StatItem(
                      icon: Icons.camera_alt_outlined,
                      iconColor: AppColors.primary,
                      label: 'Postingan',
                      value: isPostLoading ? '–' : '${posts.length}',
                    ),
                    _StatItem(
                      icon: Icons.favorite_outline_rounded,
                      iconColor: AppColors.error,
                      label: 'Total Suka',
                      value: isPostLoading ? '–' : '$totalLikes',
                    ),
                    _StatItem(
                      icon: Icons.chat_bubble_outline_rounded,
                      iconColor: AppColors.primary,
                      label: 'Komentar',
                      value: isPostLoading ? '–' : '$totalComments',
                    ),
                  ]),
                ])),
                const SizedBox(height: 16),

                // ── Card: Informasi Akun ───────────────────────────────────
                _Card(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SectionTitle('Informasi Akun'),
                    const SizedBox(height: 20),
                    _InputField(label: 'Nama Lengkap', ctrl: _nameCtrl),
                    const SizedBox(height: 14),
                    _InputField(label: 'Username', ctrl: _usernameCtrl),
                    const SizedBox(height: 14),
                    _InputField(
                      label: 'Email',
                      ctrl: _emailCtrl,
                      inputType: TextInputType.emailAddress,
                    ),
                    if (_saveError != null) ...[
                      const SizedBox(height: 12),
                      _AlertBox(isError: true, message: _saveError!),
                    ],
                    if (_saveSuccess != null) ...[
                      const SizedBox(height: 12),
                      _AlertBox(isError: false, message: _saveSuccess!),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text('Simpan Perubahan',
                                style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                )),
                const SizedBox(height: 16),

                // ── Card: Keamanan Akun ───────────────────────────────────
                _Card(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionTitle('Keamanan Akun'),
                    const SizedBox(height: 8),
                    Text(
                      'Ganti password secara berkala untuk menjaga keamanan akunmu. '
                      'Kode OTP akan dikirim ke emailmu.',
                      style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.muted, height: 1.5),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _openPasswordDialog,
                      icon: const Icon(Icons.key_rounded, size: 16),
                      label: Text('Ganti Password',
                          style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                )),
                const SizedBox(height: 24),

                // ── Dinding Foto ──────────────────────────────────────────
                Row(children: [
                  const Icon(Icons.camera_alt_outlined, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  _SectionTitle('Dinding Foto'),
                  const Spacer(),
                  if (!isPostLoading && posts.isNotEmpty)
                    Text('${posts.length} postingan',
                        style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.muted)),
                ]),
                const SizedBox(height: 12),
                if (isPostLoading)
                  _WallSkeleton()
                else if (posts.isEmpty)
                  _WallEmpty()
                else
                  _WallGrid(posts: posts, onTap: _openLightbox),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── Reusable small widgets ────────────────────────────────────────────────────
class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
      boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2))],
    ),
    child: child,
  );
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: GoogleFonts.syne(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.ink),
  );
}

class _Avatar extends StatelessWidget {
  final UserProfile profile;
  const _Avatar({required this.profile});

  @override
  Widget build(BuildContext context) => Container(
    width: 72,
    height: 72,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.primary, Color(0xFF6b8fff)],
      ),
      image: profile.profilePicture != null
          ? DecorationImage(image: NetworkImage(profile.profilePicture!), fit: BoxFit.cover)
          : null,
    ),
    alignment: Alignment.center,
    child: profile.profilePicture == null
        ? Text(profile.initials,
            style: GoogleFonts.syne(fontSize: 26, fontWeight: FontWeight.w700, color: Colors.white))
        : null,
  );
}

class _NameBlock extends StatelessWidget {
  final UserProfile profile;
  const _NameBlock({required this.profile});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(profile.displayName,
          style: GoogleFonts.syne(fontSize: 19, fontWeight: FontWeight.w700, color: AppColors.ink)),
      const SizedBox(height: 2),
      Text('@${profile.username}',
          style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.muted)),
      if (profile.isVerified) ...[
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFecfdf5),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.check_rounded, size: 11, color: Color(0xFF065f46)),
            const SizedBox(width: 4),
            Text('Terverifikasi',
                style: GoogleFonts.dmSans(
                    fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF065f46))),
          ]),
        ),
      ],
    ],
  );
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  const _StatItem(
      {required this.icon, required this.iconColor, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(children: [
      Icon(icon, size: 18, color: iconColor),
      const SizedBox(height: 4),
      Text(value,
          style: GoogleFonts.syne(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.ink)),
      Text(label, style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.muted)),
    ]),
  );
}

class _AlertBox extends StatelessWidget {
  final bool isError;
  final String message;
  const _AlertBox({required this.isError, required this.message});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: isError ? AppColors.errorBg : AppColors.primaryLighter,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(message,
        style: GoogleFonts.dmSans(
            fontSize: 13,
            color: isError ? AppColors.error : const Color(0xFF166534))),
  );
}

class _InputField extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final TextInputType inputType;
  final bool obscure;
  const _InputField(
      {required this.label,
      required this.ctrl,
      this.inputType = TextInputType.text,
      this.obscure = false});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label,
          style: GoogleFonts.dmSans(
              fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.muted)),
      const SizedBox(height: 6),
      TextField(
        controller: ctrl,
        keyboardType: inputType,
        obscureText: obscure,
        style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.ink),
        decoration: InputDecoration(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.borderNeutral)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.borderNeutral)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
          filled: true,
          fillColor: AppColors.white,
        ),
      ),
    ],
  );
}

// ─── Wall widgets ──────────────────────────────────────────────────────────────
class _WallEmpty extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
    decoration: BoxDecoration(
      border: Border.all(color: AppColors.primaryLight, width: 2),
      borderRadius: BorderRadius.circular(16),
      color: AppColors.primaryLighter,
    ),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.camera_alt_outlined, size: 40, color: AppColors.primary),
      const SizedBox(height: 12),
      Text(
        'Belum ada postingan di dinding kamu.\nShare progres habitmu dari menu Feed!',
        textAlign: TextAlign.center,
        style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.muted, height: 1.5),
      ),
    ]),
  );
}

class _WallSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) => GridView.count(
    crossAxisCount: 3,
    mainAxisSpacing: 2,
    crossAxisSpacing: 2,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    children: List.generate(6, (_) => Container(color: AppColors.border)),
  );
}

class _WallGrid extends StatelessWidget {
  final List<Post> posts;
  final void Function(Post) onTap;
  const _WallGrid({required this.posts, required this.onTap});

  @override
  Widget build(BuildContext context) => GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 3, mainAxisSpacing: 2, crossAxisSpacing: 2,
    ),
    itemCount: posts.length,
    itemBuilder: (_, i) {
      final p = posts[i];
      return GestureDetector(
        onTap: () => onTap(p),
        child: Stack(fit: StackFit.expand, children: [
          p.imageUrl != null
              ? Image.network(p.imageUrl!, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const _ImgPlaceholder())
              : const _ImgPlaceholder(),
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black54, Colors.transparent],
                ),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.favorite, size: 10, color: Colors.white),
                const SizedBox(width: 2),
                Text('${p.likesCount}',
                    style: const TextStyle(
                        fontSize: 9, color: Colors.white, fontWeight: FontWeight.w700)),
                const SizedBox(width: 5),
                const Icon(Icons.chat_bubble, size: 10, color: Colors.white),
                const SizedBox(width: 2),
                Text('${p.commentsCount}',
                    style: const TextStyle(
                        fontSize: 9, color: Colors.white, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        ]),
      );
    },
  );
}

class _ImgPlaceholder extends StatelessWidget {
  const _ImgPlaceholder();
  @override
  Widget build(BuildContext context) => Container(
    color: AppColors.primaryLighter,
    child: const Icon(Icons.image_outlined, color: AppColors.primary, size: 28),
  );
}

// ─── Change Password Dialog (3-step OTP) ──────────────────────────────────────
class _ChangePasswordDialog extends ConsumerStatefulWidget {
  final VoidCallback onSuccess;
  const _ChangePasswordDialog({required this.onSuccess});

  @override
  ConsumerState<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

enum _PwStep { request, otp, newPass }

class _ChangePasswordDialogState extends ConsumerState<_ChangePasswordDialog> {
  _PwStep _step = _PwStep.request;
  final _otpCtrl = TextEditingController();
  final _pw1Ctrl = TextEditingController();
  final _pw2Ctrl = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _savedOtp;

  @override
  void dispose() {
    _otpCtrl.dispose();
    _pw1Ctrl.dispose();
    _pw2Ctrl.dispose();
    super.dispose();
  }

  Future<void> _requestOtp() async {
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(profileRepositoryProvider).requestChangePasswordOtp();
      if (mounted) setState(() { _step = _PwStep.otp; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Gagal mengirim OTP. Coba lagi.'; _loading = false; });
    }
  }

  Future<void> _verifyOtp() async {
    if (_otpCtrl.text.length != 6) {
      setState(() => _error = 'Masukkan 6 digit kode OTP.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(profileRepositoryProvider).verifyChangePasswordOtp(_otpCtrl.text);
      if (mounted) setState(() { _savedOtp = _otpCtrl.text; _step = _PwStep.newPass; _loading = false; });
    } on DioException catch (e) {
      final msg = (e.response?.data as Map?)?['message']?.toString() ?? 'OTP salah atau kadaluarsa.';
      if (mounted) setState(() { _error = msg; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Terjadi kesalahan.'; _loading = false; });
    }
  }

  Future<void> _changePassword() async {
    if (_pw1Ctrl.text.length < 8) {
      setState(() => _error = 'Password minimal 8 karakter.');
      return;
    }
    if (_pw1Ctrl.text != _pw2Ctrl.text) {
      setState(() => _error = 'Password tidak cocok.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(profileRepositoryProvider).changePassword(
        otp: _savedOtp!,
        newPassword: _pw1Ctrl.text,
        confirmation: _pw2Ctrl.text,
      );
      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
      }
    } on DioException catch (e) {
      final msg = (e.response?.data as Map?)?['message']?.toString() ?? 'Gagal mengganti password.';
      if (mounted) setState(() { _error = msg; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Terjadi kesalahan.'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    const titles = {
      _PwStep.request: 'Verifikasi Identitas',
      _PwStep.otp:     'Masukkan Kode OTP',
      _PwStep.newPass: 'Buat Password Baru',
    };
    const subtitles = {
      _PwStep.request: 'Kode OTP akan dikirim ke emailmu untuk verifikasi.',
      _PwStep.otp:     'Masukkan 6 digit kode yang dikirim ke emailmu.',
      _PwStep.newPass: 'Buat password baru yang kuat (minimal 8 karakter).',
    };
    const icons = {
      _PwStep.request: Icons.lock_outline_rounded,
      _PwStep.otp:     Icons.mail_outline_rounded,
      _PwStep.newPass: Icons.key_rounded,
    };
    final steps     = _PwStep.values;
    final stepIndex = steps.indexOf(_step);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 24, right: 24, top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icons[_step], size: 40, color: AppColors.primary),
          const SizedBox(height: 12),
          Text(titles[_step]!,
              style: GoogleFonts.syne(
                  fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.ink)),
          const SizedBox(height: 6),
          Text(subtitles[_step]!,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.muted, height: 1.4)),
          const SizedBox(height: 16),
          // Step dots
          Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(steps.length, (i) {
            final active = i == stepIndex;
            final done   = i < stepIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: active
                    ? AppColors.primary
                    : done
                        ? AppColors.primaryLight
                        : const Color(0xFFd1fae5),
                borderRadius: BorderRadius.circular(4),
              ),
            );
          })),
          const SizedBox(height: 20),
          if (_error != null) ...[
            _AlertBox(isError: true, message: _error!),
            const SizedBox(height: 12),
          ],
          // Step content
          if (_step == _PwStep.request)
            _PrimaryBtn(label: 'Kirim Kode OTP', loading: _loading, onTap: _requestOtp),
          if (_step == _PwStep.otp) ...[
            TextField(
              controller: _otpCtrl,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                  fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: 8),
              decoration: InputDecoration(
                hintText: '000000',
                counterText: '',
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.borderNeutral)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
              ),
            ),
            const SizedBox(height: 12),
            _PrimaryBtn(label: 'Verifikasi OTP', loading: _loading, onTap: _verifyOtp),
            const SizedBox(height: 6),
            TextButton(
              onPressed: _loading ? null : _requestOtp,
              child: Text('Kirim ulang OTP',
                  style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.primary)),
            ),
          ],
          if (_step == _PwStep.newPass) ...[
            _InputField(label: 'Password Baru', ctrl: _pw1Ctrl, obscure: true),
            const SizedBox(height: 12),
            _InputField(label: 'Konfirmasi Password', ctrl: _pw2Ctrl, obscure: true),
            const SizedBox(height: 12),
            _PrimaryBtn(label: 'Simpan Password', loading: _loading, onTap: _changePassword),
          ],
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal', style: GoogleFonts.dmSans(color: AppColors.muted)),
          ),
        ]),
      ),
    );
  }
}

class _PrimaryBtn extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback? onTap;
  const _PrimaryBtn({required this.label, required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 48,
    child: ElevatedButton(
      onPressed: loading ? null : onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: loading
          ? const SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : Text(label, style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w600)),
    ),
  );
}
