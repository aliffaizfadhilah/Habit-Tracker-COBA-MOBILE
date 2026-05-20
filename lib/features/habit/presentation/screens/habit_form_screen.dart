import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/habit_model.dart';
import '../providers/habit_provider.dart';

// Color per category value
const _categoryColors = <String, Color>{
  'kesehatan':        Color(0xFFf97316),
  'ilmu_pengetahuan': Color(0xFF10b981),
  'spiritual':        Color(0xFF6366f1),
  'finansial':        Color(0xFF0ea5e9),
  'personal':         Color(0xFFec4899),
  'lainnya':          Color(0xFF8b5cf6),
};

Color _catColor(String value) => _categoryColors[value] ?? AppColors.primary;

class HabitFormSheet extends StatefulWidget {
  final Habit? habit;
  final WidgetRef ref;

  const HabitFormSheet({super.key, this.habit, required this.ref});

  @override
  State<HabitFormSheet> createState() => _HabitFormSheetState();
}

class _HabitFormSheetState extends State<HabitFormSheet> {
  final _titleCtrl = TextEditingController();
  final _customCategoryCtrl = TextEditingController();

  // stored as lowercase backend value ('kesehatan', 'lainnya', etc.)
  String? _category;
  DateTime? _periodeStart;
  DateTime? _periodeEnd;
  TimeOfDay? _reminderTime;
  bool _loading = false;
  String? _error;

  bool get _isEdit => widget.habit != null;
  bool get _isLainnya => _category == 'lainnya';

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final h = widget.habit!;
      _titleCtrl.text = h.title;

      // Map stored category to one of the 6 options
      final norm = h.category.toLowerCase().replaceAll(' ', '_');
      if (standardCategoryValues.contains(norm)) {
        _category = norm;
      } else {
        _category = 'lainnya';
        _customCategoryCtrl.text = h.category;
      }

      if (h.periodeStart != null) _periodeStart = DateTime.tryParse(h.periodeStart!);
      if (h.periodeEnd != null) _periodeEnd = DateTime.tryParse(h.periodeEnd!);
      if (h.reminderTime != null) {
        final parts = h.reminderTime!.split(':');
        _reminderTime = TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 7,
          minute: int.tryParse(parts[1]) ?? 0,
        );
      }
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _customCategoryCtrl.dispose();
    super.dispose();
  }

  String _formatDate(DateTime? d) =>
      d == null ? 'Pilih tanggal' : DateFormat('d MMM yyyy').format(d);

  String _formatTime(TimeOfDay? t) =>
      t == null ? 'Pilih waktu' : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? (_periodeStart ?? now) : (_periodeEnd ?? _periodeStart ?? now),
      firstDate: isStart ? DateTime(2020) : (_periodeStart ?? DateTime(2020)),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            surface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _periodeStart = picked;
          if (_periodeEnd != null && _periodeEnd!.isBefore(picked)) _periodeEnd = null;
        } else {
          _periodeEnd = picked;
        }
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime ?? const TimeOfDay(hour: 7, minute: 0),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _reminderTime = picked);
  }

  String? _resolvedCategory() {
    if (_category == null) return null;
    if (_category == 'lainnya') {
      final custom = _customCategoryCtrl.text.trim();
      return custom.isEmpty ? null : custom;
    }
    return _category;
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Judul habit wajib diisi');
      return;
    }
    if (_category == null) {
      setState(() => _error = 'Kategori wajib dipilih');
      return;
    }
    if (_isLainnya && _customCategoryCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Nama kategori kustom wajib diisi');
      return;
    }
    if (_periodeStart == null) {
      setState(() => _error = 'Tanggal mulai wajib diisi');
      return;
    }
    if (_periodeEnd == null) {
      setState(() => _error = 'Tanggal selesai wajib diisi');
      return;
    }
    if (_reminderTime == null) {
      setState(() => _error = 'Waktu pengingat wajib diisi');
      return;
    }

    setState(() { _loading = true; _error = null; });

    final categoryValue = _resolvedCategory()!;
    final timeStr = _formatTime(_reminderTime);
    final startStr = DateFormat('yyyy-MM-dd').format(_periodeStart!);
    final endStr   = DateFormat('yyyy-MM-dd').format(_periodeEnd!);

    try {
      if (_isEdit) {
        await widget.ref.read(habitListProvider.notifier).editHabit(
          widget.habit!.idHabit,
          title: _titleCtrl.text.trim(),
          category: categoryValue,
          periodeStart: startStr,
          periodeEnd: endStr,
          reminderTime: timeStr,
        );
      } else {
        await widget.ref.read(habitListProvider.notifier).addHabit(
          title: _titleCtrl.text.trim(),
          category: categoryValue,
          periodeStart: startStr,
          periodeEnd: endStr,
          reminderTime: timeStr,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (_) {
      setState(() => _error = 'Gagal menyimpan habit. Coba lagi.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
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
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _isEdit ? 'Edit Habit' : 'Tambah Habit',
              style: GoogleFonts.syne(
                fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.ink),
            ),
            const SizedBox(height: 20),

            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.errorBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                ),
                child: Row(children: [
                  const Icon(Icons.error_outline_rounded, size: 15, color: AppColors.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_error!,
                      style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.error)),
                  ),
                ]),
              ),
              const SizedBox(height: 16),
            ],

            // ── Title ──────────────────────────────────────────────────────────
            _Label('Judul habit'),
            const SizedBox(height: 6),
            TextField(
              controller: _titleCtrl,
              autofocus: !_isEdit,
              style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.ink),
              decoration: _inputDecoration('Contoh: Olahraga 30 menit'),
            ),
            const SizedBox(height: 16),

            // ── Category chips ─────────────────────────────────────────────────
            _Label('Kategori'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: habitCategoryOptions.map((opt) {
                final selected = _category == opt.value;
                final color = _catColor(opt.value);
                return GestureDetector(
                  onTap: () => setState(() => _category = opt.value),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected ? color.withValues(alpha: 0.12) : AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected ? color : AppColors.border,
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Text(
                      opt.label,
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected ? color : AppColors.muted,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            // ── Custom category input (for Lainnya) ────────────────────────────
            if (_isLainnya) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _customCategoryCtrl,
                style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.ink),
                decoration: _inputDecoration('Nama kategori kustom...'),
                onChanged: (_) => setState(() {}),
              ),
            ],
            const SizedBox(height: 16),

            // ── Dates ──────────────────────────────────────────────────────────
            Row(children: [
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Label('Tanggal mulai'),
                  const SizedBox(height: 6),
                  _DateTile(
                    label: _formatDate(_periodeStart),
                    icon: Icons.calendar_today_outlined,
                    hasValue: _periodeStart != null,
                    onTap: () => _pickDate(isStart: true),
                  ),
                ],
              )),
              const SizedBox(width: 10),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Label('Tanggal selesai'),
                  const SizedBox(height: 6),
                  _DateTile(
                    label: _formatDate(_periodeEnd),
                    icon: Icons.calendar_today_outlined,
                    hasValue: _periodeEnd != null,
                    onTap: () => _pickDate(isStart: false),
                  ),
                ],
              )),
            ]),
            const SizedBox(height: 16),

            // ── Reminder time ──────────────────────────────────────────────────
            _Label('Waktu pengingat'),
            const SizedBox(height: 6),
            _DateTile(
              label: _reminderTime == null
                  ? 'Pilih waktu'
                  : 'Setiap hari pukul ${_formatTime(_reminderTime)}',
              icon: Icons.access_time_rounded,
              hasValue: _reminderTime != null,
              onTap: _pickTime,
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _save,
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
                    : Text(
                        _isEdit ? 'Simpan perubahan' : 'Tambah habit',
                        style: GoogleFonts.dmSans(
                          fontSize: 15, fontWeight: FontWeight.w600),
                      ),
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

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: GoogleFonts.dmSans(
          fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.inkBody),
      );
}

class _DateTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool hasValue;
  final VoidCallback onTap;

  const _DateTile({
    required this.label, required this.icon,
    required this.hasValue, required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasValue ? AppColors.borderMid : AppColors.border,
              width: 1.5,
            ),
          ),
          child: Row(children: [
            Icon(icon, size: 16, color: hasValue ? AppColors.primary : AppColors.subtle),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: hasValue ? AppColors.ink : AppColors.subtle,
                  fontWeight: hasValue ? FontWeight.w500 : FontWeight.w400,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ]),
        ),
      );
}
