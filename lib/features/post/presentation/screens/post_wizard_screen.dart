import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../habit/domain/habit_model.dart';
import '../../../habit/presentation/providers/habit_provider.dart';
import '../providers/post_provider.dart';

// ─── Element model (mirrors snapshot_sheet.dart) ──────────────────────────────

enum _ElemId { title, diagram, stats, branding }

const _elemLabels = {
  _ElemId.title:    'Judul & Kategori',
  _ElemId.diagram:  'Diagram Progress',
  _ElemId.stats:    'Statistik',
  _ElemId.branding: 'Watermark',
};

class _Elem {
  final _ElemId id;
  double x;        // 0-100 % from left (element centered on this point)
  double y;        // 0-100 % from top
  double fontSize;
  _Elem({required this.id, required this.x, required this.y, required this.fontSize});
}

List<_Elem> _defaultElems() => [
  _Elem(id: _ElemId.title,    x: 50, y: 16, fontSize: 24),
  _Elem(id: _ElemId.diagram,  x: 50, y: 44, fontSize: 14),
  _Elem(id: _ElemId.stats,    x: 50, y: 74, fontSize: 13),
  _Elem(id: _ElemId.branding, x: 50, y: 90, fontSize: 11),
];

// ─── Wizard Screen ────────────────────────────────────────────────────────────

class PostWizardScreen extends ConsumerStatefulWidget {
  const PostWizardScreen({super.key});

  @override
  ConsumerState<PostWizardScreen> createState() => _PostWizardScreenState();
}

class _PostWizardScreenState extends ConsumerState<PostWizardScreen> {
  int _step = 0;

  // Preview fixed size (same aspect ratio as snapshot_sheet)
  static const double _prevW = 256;
  static const double _prevH = 455;

  // Step 1
  Habit? _habit;
  String _habitSearch = '';

  // Step 2 – background zoom/pan
  File? _bgFile;
  double _bgScale = 1.0;
  double _bgScaleStart = 1.0;
  Offset _bgOffset = Offset.zero;

  // Step 2 – elements
  bool _arcMode = false;
  _ElemId? _selectedId;
  late List<_Elem> _elems;
  final _previewKey = GlobalKey();
  bool _capturing = false;

  // Step 3
  File? _snapshotFile;
  late final TextEditingController _titleCtrl;
  late final TextEditingController _captionCtrl;
  bool _isPublic = true;
  bool _posting = false;
  String? _postError;

  @override
  void initState() {
    super.initState();
    _elems = _defaultElems();
    _titleCtrl = TextEditingController();
    _captionCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _captionCtrl.dispose();
    super.dispose();
  }

  // ─── Step 1 helpers ──────────────────────────────────────────────────────────

  void _selectHabit(Habit habit) {
    setState(() {
      _habit = habit;
      _titleCtrl.text = habit.title;
      _step = 1;
    });
  }

  // ─── Step 2 helpers ──────────────────────────────────────────────────────────

  Future<void> _pickBg(ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source, imageQuality: 90);
    if (picked != null && mounted) setState(() => _bgFile = File(picked.path));
  }

  Future<void> _goToStep3() async {
    if (_bgFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih gambar latar belakang terlebih dahulu.')),
      );
      return;
    }
    setState(() { _selectedId = null; _capturing = true; });
    await Future.delayed(const Duration(milliseconds: 80));
    try {
      final boundary = _previewKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) { if (mounted) setState(() => _capturing = false); return; }
      final image = await boundary.toImage(pixelRatio: 3.0);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) { if (mounted) setState(() => _capturing = false); return; }
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/snap_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(data.buffer.asUint8List());
      if (!mounted) return;
      setState(() { _snapshotFile = file; _step = 2; _capturing = false; });
    } catch (_) {
      if (mounted) setState(() => _capturing = false);
    }
  }

  // ─── Step 3 helpers ──────────────────────────────────────────────────────────

  Future<void> _post() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) { setState(() => _postError = 'Judul tidak boleh kosong.'); return; }
    if (_snapshotFile == null) { setState(() => _postError = 'Snapshot tidak tersedia.'); return; }
    setState(() { _posting = true; _postError = null; });
    try {
      await ref.read(feedProvider.notifier).addPost(
        title: title,
        caption: _captionCtrl.text.trim().isEmpty ? null : _captionCtrl.text.trim(),
        imagePath: _snapshotFile!.path,
        habitId: _habit?.idHabit,
        habitTitle: _habit?.title,
        progressPercent: _habit?.progressPercent,
        isPrivate: !_isPublic,
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() { _postError = 'Gagal memposting. Coba lagi.'; _posting = false; });
    }
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _step > 0) setState(() => _step--);
      },
      child: Scaffold(
        backgroundColor: _step == 1 ? Colors.black : AppColors.white,
        body: SafeArea(child: _buildBody()),
      ),
    );
  }

  Widget _buildBody() {
    return switch (_step) {
      0 => _buildStep1(),
      1 => _buildStep2(),
      2 => _buildStep3(),
      _ => const SizedBox.shrink(),
    };
  }

  // ─── Step 1: Habit Picker ─────────────────────────────────────────────────────

  Widget _buildStep1() {
    final habitsAsync = ref.watch(habitListProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: AppColors.ink),
              ),
              Expanded(
                child: Text('Pilih Habit',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.syne(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.ink)),
              ),
              const SizedBox(width: 48),
            ],
          ),
        ),
        _StepDots(step: 0, dark: false),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            onChanged: (v) => setState(() => _habitSearch = v),
            style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.ink),
            decoration: InputDecoration(
              hintText: 'Cari habit...',
              hintStyle: GoogleFonts.dmSans(color: AppColors.subtle),
              prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.subtle),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: habitsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
            error: (e, _) => Center(child: Text('Gagal memuat habit.', style: GoogleFonts.dmSans(color: AppColors.error))),
            data: (habits) {
              final q = _habitSearch.toLowerCase();
              final filtered = q.isEmpty
                  ? habits
                  : habits.where((h) =>
                      h.title.toLowerCase().contains(q) ||
                      h.categoryDisplay.toLowerCase().contains(q)).toList();
              if (filtered.isEmpty) {
                return Center(child: Text('Tidak ada habit ditemukan.', style: GoogleFonts.dmSans(color: AppColors.subtle)));
              }
              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _HabitTile(habit: filtered[i], onTap: () => _selectHabit(filtered[i])),
              );
            },
          ),
        ),
      ],
    );
  }

  // ─── Step 2: Snapshot Builder ─────────────────────────────────────────────────

  Widget _buildStep2() {
    return Column(
      children: [
        // Top bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () => setState(() => _step = 0),
              ),
              Expanded(child: _StepDots(step: 1, dark: true)),
              TextButton(
                onPressed: _capturing ? null : _goToStep3,
                child: _capturing
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('Selanjutnya →',
                        style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),

        // Preview centered
        Expanded(
          child: Center(child: _buildPreview()),
        ),

        // Controls (scrollable)
        SizedBox(
          height: 280,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              children: [
                _buildBgSection(),
                const SizedBox(height: 10),
                _buildDiagramSection(),
                const SizedBox(height: 10),
                _buildSelectedSection(),
                const SizedBox(height: 10),
                _buildAllElemsSection(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreview() {
    return GestureDetector(
      // outer: handles 2-finger zoom + 1-finger pan on empty area
      onScaleStart: (d) => _bgScaleStart = _bgScale,
      onScaleUpdate: (d) {
        setState(() {
          if (d.pointerCount >= 2) {
            _bgScale = (_bgScaleStart * d.scale).clamp(0.5, 5.0);
          }
          _bgOffset += d.focalPointDelta;
        });
      },
      child: RepaintBoundary(
        key: _previewKey,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            width: _prevW,
            height: _prevH,
            child: Stack(
              children: [
                // Base
                Positioned.fill(child: Container(color: const Color(0xFF0f2018))),

                // Background with zoom/pan
                if (_bgFile != null)
                  Positioned.fill(
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..translate(_bgOffset.dx, _bgOffset.dy)
                        ..scale(_bgScale),
                      child: Image.file(_bgFile!, fit: BoxFit.cover, width: _prevW, height: _prevH),
                    ),
                  ),

                // Gradient overlay
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: _bgFile != null
                            ? [const Color(0x47000000), const Color(0x9E000000)]
                            : [const Color(0x8C2B59FF), const Color(0x5910B981)],
                      ),
                    ),
                  ),
                ),

                // Hint when no image
                if (_bgFile == null)
                  const Positioned.fill(
                    child: Center(
                      child: Text(
                        'Pilih foto latar\ndari panel bawah',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0x66FFFFFF), fontSize: 12),
                      ),
                    ),
                  ),

                // Overlay elements
                ..._elems.map(_buildPositionedElem),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPositionedElem(_Elem el) {
    final isSelected = _selectedId == el.id;
    return Positioned(
      left: el.x / 100 * _prevW,
      top: el.y / 100 * _prevH,
      child: GestureDetector(
        onTap: () => setState(() => _selectedId = _selectedId == el.id ? null : el.id),
        onPanUpdate: (d) => setState(() {
          el.x = (el.x + d.delta.dx / _prevW * 100).clamp(5, 95);
          el.y = (el.y + d.delta.dy / _prevH * 100).clamp(5, 95);
        }),
        child: FractionalTranslation(
          translation: const Offset(-0.5, -0.5),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: isSelected ? Colors.white.withAlpha(30) : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
              border: isSelected
                  ? Border.all(color: Colors.white.withAlpha(204), width: 1.5)
                  : null,
            ),
            child: _buildElemContent(el),
          ),
        ),
      ),
    );
  }

  Widget _buildElemContent(_Elem el) {
    final fs = el.fontSize;
    final habit = _habit;
    switch (el.id) {
      case _ElemId.title:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              habit?.title ?? 'Judul Habit',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: fs,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                shadows: const [Shadow(color: Colors.black54, blurRadius: 8)],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              habit?.categoryDisplay ?? 'Kategori',
              style: TextStyle(
                fontSize: fs * 0.55,
                color: Colors.white.withAlpha(204),
                shadows: const [Shadow(color: Colors.black38, blurRadius: 4)],
              ),
            ),
          ],
        );

      case _ElemId.diagram:
        final size = fs * 8;
        final progress = habit?.progressPercent ?? 0;
        return _arcMode
            ? CustomPaint(
                size: Size(size, size * 0.78),
                painter: WizardArcPainter(progress))
            : CustomPaint(
                size: Size(size, size),
                painter: WizardDonutPainter(progress));

      case _ElemId.stats:
        final streak = habit?.currentStreak ?? 0;
        final selesai = habit?.totalCompletedDays ?? 0;
        final longest = habit?.longestStreak ?? 0;
        final items = [
          ('🔥', '$streak', 'Streak'),
          ('✅', '$selesai', 'Selesai'),
          ('🏆', '$longest', 'Longest'),
        ];
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: items.map((s) => Padding(
            padding: EdgeInsets.symmetric(horizontal: fs * 0.8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(s.$1, style: TextStyle(fontSize: fs * 1.5)),
                Text(s.$2, style: TextStyle(
                  fontSize: fs * 1.1, fontWeight: FontWeight.w800, color: Colors.white,
                  shadows: const [Shadow(color: Colors.black38, blurRadius: 4)],
                )),
                Text(s.$3, style: TextStyle(
                  fontSize: fs * 0.75, color: Colors.white.withAlpha(191),
                )),
              ],
            ),
          )).toList(),
        );

      case _ElemId.branding:
        return Text(
          '🌿 HabitTracker',
          style: TextStyle(
            fontSize: fs,
            color: Colors.white.withAlpha(166),
            shadows: const [Shadow(color: Colors.black26, blurRadius: 3)],
          ),
        );
    }
  }

  // ─── Control sections (same style as snapshot_sheet) ─────────────────────────

  Widget _sectionCard({required String label, required IconData icon, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 13, color: AppColors.muted),
            const SizedBox(width: 6),
            Text(label, style: GoogleFonts.dmSans(
                fontSize: 11, fontWeight: FontWeight.w700,
                color: AppColors.muted, letterSpacing: 0.8)),
          ]),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildBgSection() {
    return _sectionCard(
      label: 'FOTO LATAR',
      icon: Icons.camera_alt_outlined,
      child: Column(
        children: [
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickBg(ImageSource.gallery),
                icon: const Icon(Icons.folder_open_outlined, size: 14),
                label: Text('Pilih Galeri',
                    style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.borderMid),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _pickBg(ImageSource.camera),
                icon: const Icon(Icons.camera_alt_outlined, size: 14),
                label: Text('Kamera', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ]),
          if (_bgFile != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => setState(() {
                  _bgFile = null;
                  _bgScale = 1.0;
                  _bgOffset = Offset.zero;
                }),
                icon: const Icon(Icons.close_rounded, size: 13),
                label: Text('Hapus foto', style: GoogleFonts.dmSans(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.muted,
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
          if (_bgFile != null) ...[
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.info_outline_rounded, size: 11, color: AppColors.muted),
              const SizedBox(width: 4),
              Text('Cubit 2 jari untuk zoom • 1 jari pada area kosong untuk geser',
                  style: GoogleFonts.dmSans(fontSize: 10, color: AppColors.muted)),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _buildDiagramSection() {
    return _sectionCard(
      label: 'TIPE DIAGRAM',
      icon: Icons.donut_large_outlined,
      child: Row(children: [
        Expanded(child: _WizardDiagramBtn(
            label: 'Donut', icon: Icons.circle_outlined,
            selected: !_arcMode, onTap: () => setState(() => _arcMode = false))),
        const SizedBox(width: 8),
        Expanded(child: _WizardDiagramBtn(
            label: 'Arc', icon: Icons.nights_stay_outlined,
            selected: _arcMode, onTap: () => setState(() => _arcMode = true))),
      ]),
    );
  }

  _Elem? get _selected =>
      _selectedId == null ? null : _elems.firstWhere((e) => e.id == _selectedId!);

  Widget _buildSelectedSection() {
    final sel = _selected;
    return _sectionCard(
      label: 'ELEMEN TERPILIH',
      icon: Icons.gps_fixed_outlined,
      child: sel == null
          ? Text('Ketuk elemen di preview untuk memilihnya.',
              style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.muted, fontStyle: FontStyle.italic))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_elemLabels[sel.id]!,
                    style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink)),
                const SizedBox(height: 8),
                Row(children: [
                  Text('Ukuran:', style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.muted)),
                  const SizedBox(width: 8),
                  _SizeBtn(label: '−', onTap: () => setState(() => sel.fontSize = (sel.fontSize - 2).clamp(8, 48))),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 30,
                    child: Text(sel.fontSize.toStringAsFixed(0),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink)),
                  ),
                  const SizedBox(width: 8),
                  _SizeBtn(label: '+', onTap: () => setState(() => sel.fontSize = (sel.fontSize + 2).clamp(8, 48))),
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.info_outline_rounded, size: 11, color: AppColors.muted),
                  const SizedBox(width: 4),
                  Text('Drag elemen di preview untuk memindahkan.',
                      style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.muted)),
                ]),
              ],
            ),
    );
  }

  Widget _buildAllElemsSection() {
    return _sectionCard(
      label: 'SEMUA ELEMEN',
      icon: Icons.list_alt_outlined,
      child: Column(
        children: _elems.map((el) {
          final selected = _selectedId == el.id;
          return GestureDetector(
            onTap: () => setState(() => _selectedId = selected ? null : el.id),
            child: Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? AppColors.primaryLight : AppColors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: selected ? AppColors.primary : AppColors.border, width: 1.5),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(_elemLabels[el.id]!,
                        style: GoogleFonts.dmSans(
                            fontSize: 12, fontWeight: FontWeight.w600,
                            color: selected ? AppColors.primary : AppColors.ink)),
                  ),
                  Text(
                    '${el.fontSize.toStringAsFixed(0)}px • (${el.x.toStringAsFixed(0)}%, ${el.y.toStringAsFixed(0)}%)',
                    style: GoogleFonts.dmSans(fontSize: 10, color: AppColors.muted),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── Step 3: Post Details ─────────────────────────────────────────────────────

  Widget _buildStep3() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: AppColors.ink),
                onPressed: () => setState(() => _step = 1),
              ),
              Expanded(
                child: Text('Detail Postingan',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.syne(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.ink)),
              ),
              const SizedBox(width: 48),
            ],
          ),
        ),
        _StepDots(step: 2, dark: false),
        const SizedBox(height: 8),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Full snapshot preview (no crop)
                if (_snapshotFile != null)
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(
                        _snapshotFile!,
                        // Use contain so full image is visible without cropping
                        fit: BoxFit.contain,
                        width: double.infinity,
                      ),
                    ),
                  ),
                const SizedBox(height: 14),

                // Habit badge
                if (_habit != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.eco_rounded, size: 13, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(_habit!.title,
                            style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                const SizedBox(height: 14),

                // Error banner
                if (_postError != null) ...[
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
                      Expanded(child: Text(_postError!,
                          style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.error))),
                    ]),
                  ),
                  const SizedBox(height: 12),
                ],

                // Title
                Text('Judul', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.inkBody)),
                const SizedBox(height: 6),
                TextField(
                  controller: _titleCtrl,
                  style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.ink),
                  decoration: _inputDeco('Judul postingan...'),
                ),
                const SizedBox(height: 12),

                // Caption
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Deskripsi (opsional)',
                        style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.inkBody)),
                    ValueListenableBuilder(
                      valueListenable: _captionCtrl,
                      builder: (_, val, __) => Text('${val.text.length}/1000',
                          style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.subtle)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _captionCtrl,
                  maxLines: 3,
                  maxLength: 1000,
                  buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                  style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.ink),
                  decoration: _inputDeco('Ceritakan pencapaian habit kamu...'),
                ),
                const SizedBox(height: 14),

                // Public / Private
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isPublic ? Icons.public_rounded : Icons.lock_outline_rounded,
                        size: 18, color: AppColors.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_isPublic ? 'Publik' : 'Privat',
                                style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink)),
                            Text(
                              _isPublic ? 'Semua orang dapat melihat' : 'Hanya kamu yang dapat melihat',
                              style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.subtle),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _isPublic,
                        onChanged: (v) => setState(() => _isPublic = v),
                        activeColor: AppColors.primary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Post button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _posting ? null : _post,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: _posting
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text('Posting →',
                            style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDeco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.dmSans(color: AppColors.subtle),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border, width: 1.5)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border, width: 1.5)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
        filled: true,
        fillColor: AppColors.white,
      );
}

// ─── Painters (same logic as snapshot_sheet, public for reuse) ────────────────

class WizardDonutPainter extends CustomPainter {
  final double progress;
  const WizardDonutPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = size.width * 0.34;
    final sw = r * 0.32;

    canvas.drawCircle(Offset(cx, cy), r,
        Paint()
          ..color = Colors.white.withAlpha(56)
          ..style = PaintingStyle.stroke
          ..strokeWidth = sw
          ..strokeCap = StrokeCap.round);

    final sweep = 2 * 3.14159265 * (progress.clamp(0, 100) / 100);
    canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        -1.5707963, sweep, false,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = sw
          ..strokeCap = StrokeCap.round);

    void drawText(String text, double fontSize, Color color, double dy) {
      final tp = TextPainter(
        text: TextSpan(text: text, style: TextStyle(color: color, fontSize: fontSize, fontWeight: FontWeight.w800)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, cy + dy - tp.height / 2));
    }
    drawText('${progress.toStringAsFixed(0)}%', size.width * 0.2, Colors.white, -size.width * 0.07);
    drawText('Progress', size.width * 0.1, Colors.white.withAlpha(191), size.width * 0.1);
  }

  @override
  bool shouldRepaint(WizardDonutPainter o) => o.progress != progress;
}

class WizardArcPainter extends CustomPainter {
  final double progress;
  const WizardArcPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.72;
    final r  = size.width * 0.37;
    final sw = r * 0.24;

    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r),
        3.14159265, 3.14159265, false,
        Paint()
          ..color = Colors.white.withAlpha(56)
          ..style = PaintingStyle.stroke
          ..strokeWidth = sw
          ..strokeCap = StrokeCap.round);

    final sweep = 3.14159265 * (progress.clamp(0, 100) / 100);
    if (sweep > 0.01) {
      canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r),
          3.14159265, sweep, false,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = sw
            ..strokeCap = StrokeCap.round);
    }

    void drawText(String text, double fontSize, Color color, double dy) {
      final tp = TextPainter(
        text: TextSpan(text: text, style: TextStyle(color: color, fontSize: fontSize, fontWeight: FontWeight.w800)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, cy + dy - tp.height / 2));
    }
    drawText('${progress.toStringAsFixed(0)}%', r * 0.5, Colors.white, -r * 0.38);
    drawText('Progress', r * 0.24, Colors.white.withAlpha(191), -r * 0.06);
  }

  @override
  bool shouldRepaint(WizardArcPainter o) => o.progress != progress;
}

// ─── Helper widgets ───────────────────────────────────────────────────────────

class _StepDots extends StatelessWidget {
  final int step;
  final bool dark;
  const _StepDots({required this.step, required this.dark});

  @override
  Widget build(BuildContext context) {
    final activeColor = dark ? Colors.white : AppColors.primary;
    final inactiveColor = dark ? Colors.white24 : AppColors.border;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final active = i == step;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? activeColor : inactiveColor,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

class _HabitTile extends StatelessWidget {
  final Habit habit;
  final VoidCallback onTap;
  const _HabitTile({required this.habit, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final progress = (habit.progressPercent / 100).clamp(0.0, 1.0);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 48, height: 48,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: progress,
                    backgroundColor: AppColors.border,
                    color: AppColors.primary,
                    strokeWidth: 4,
                  ),
                  Text('${habit.progressPercent.toInt()}%',
                      style: GoogleFonts.dmSans(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.primary)),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(habit.title,
                      style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink)),
                  Text(habit.categoryDisplay,
                      style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.muted)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.subtle),
          ],
        ),
      ),
    );
  }
}

class _WizardDiagramBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _WizardDiagramBtn({required this.label, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: selected ? AppColors.primaryLight : AppColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: selected ? AppColors.primary : AppColors.border, width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: selected ? AppColors.primary : AppColors.muted),
          const SizedBox(width: 6),
          Text(label, style: GoogleFonts.dmSans(
              fontSize: 13, fontWeight: FontWeight.w600,
              color: selected ? AppColors.primary : AppColors.muted)),
        ],
      ),
    ),
  );
}

class _SizeBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _SizeBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 28, height: 28,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Center(
        child: Text(label,
            style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink)),
      ),
    ),
  );
}
