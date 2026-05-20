import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_colors.dart';
import '../providers/post_provider.dart';

class PostFormSheet extends ConsumerStatefulWidget {
  /// When set, the form opens with this image pre-loaded (e.g. from snapshot)
  final File? initialImage;
  const PostFormSheet({super.key, this.initialImage});

  @override
  ConsumerState<PostFormSheet> createState() => _PostFormSheetState();
}

class _PostFormSheetState extends ConsumerState<PostFormSheet> {
  final _titleCtrl   = TextEditingController();
  final _captionCtrl = TextEditingController();
  File? _image;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _image = widget.initialImage;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _captionCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source, imageQuality: 85);
    if (picked != null) setState(() => _image = File(picked.path));
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Judul postingan wajib diisi.');
      return;
    }
    if (_image == null) {
      setState(() => _error = 'Gambar wajib ditambahkan.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(feedProvider.notifier).addPost(
            title: title,
            caption: _captionCtrl.text.trim().isEmpty ? null : _captionCtrl.text.trim(),
            imagePath: _image!.path,
          );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _error = 'Gagal memposting. Coba lagi.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                    color: AppColors.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 18),
            Text('Buat Postingan',
                style: GoogleFonts.syne(
                    fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.ink)),
            const SizedBox(height: 16),

            // Error banner
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.errorBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.error.withAlpha(77)),
                ),
                child: Row(children: [
                  const Icon(Icons.error_outline_rounded, size: 15, color: AppColors.error),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(_error!,
                          style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.error))),
                ]),
              ),
              const SizedBox(height: 12),
            ],

            // Image picker
            _image != null
                ? Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.file(
                          _image!,
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 8, right: 8,
                        child: GestureDetector(
                          onTap: () => setState(() => _image = null),
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(20)),
                            child: const Icon(Icons.close_rounded,
                                size: 16, color: Colors.white),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 8, right: 8,
                        child: GestureDetector(
                          onTap: () => _pickImage(ImageSource.gallery),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                                color: Colors.black45,
                                borderRadius: BorderRadius.circular(20)),
                            child: Text('Ganti foto',
                                style: GoogleFonts.dmSans(
                                    fontSize: 11, color: Colors.white)),
                          ),
                        ),
                      ),
                    ],
                  )
                : GestureDetector(
                    onTap: () => _pickImage(ImageSource.gallery),
                    child: Container(
                      height: 140,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: AppColors.borderMid,
                            width: 1.5,
                            style: BorderStyle.solid),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 48, height: 48,
                            decoration: BoxDecoration(
                                color: AppColors.primaryLighter,
                                borderRadius: BorderRadius.circular(14)),
                            child: const Icon(Icons.add_photo_alternate_outlined,
                                size: 24, color: AppColors.primary),
                          ),
                          const SizedBox(height: 8),
                          Text('Tambahkan foto',
                              style: GoogleFonts.dmSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary)),
                          Text('Ketuk untuk memilih dari galeri',
                              style: GoogleFonts.dmSans(
                                  fontSize: 11, color: AppColors.muted)),
                        ],
                      ),
                    ),
                  ),
            const SizedBox(height: 14),

            // Title
            Text('Judul',
                style: GoogleFonts.dmSans(
                    fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.inkBody)),
            const SizedBox(height: 6),
            TextField(
              controller: _titleCtrl,
              style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.ink),
              decoration: _inputDecoration('Contoh: Hari pertama lari pagi'),
            ),
            const SizedBox(height: 12),

            // Caption
            Text('Deskripsi (opsional)',
                style: GoogleFonts.dmSans(
                    fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.inkBody)),
            const SizedBox(height: 6),
            TextField(
              controller: _captionCtrl,
              maxLines: 3,
              style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.ink),
              decoration: _inputDecoration('Ceritakan pencapaian habit kamu...'),
            ),
            const SizedBox(height: 18),

            // Submit button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: _loading
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text('Posting →',
                        style: GoogleFonts.dmSans(
                            fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.dmSans(color: AppColors.subtle),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        filled: true,
        fillColor: AppColors.white,
      );
}
