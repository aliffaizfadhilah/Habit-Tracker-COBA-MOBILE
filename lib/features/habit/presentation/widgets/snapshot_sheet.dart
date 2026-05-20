import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/habit_model.dart';

// ─── Element model ────────────────────────────────────────────────────────────

enum _ElemId { title, diagram, stats, branding }

class _Elem {
  _ElemId id;
  double x; // 0-100 % from left (element centered on this point)
  double y; // 0-100 % from top
  double fontSize;
  _Elem({required this.id, required this.x, required this.y, required this.fontSize});
}

const _elemLabels = {
  _ElemId.title:    'Judul & Kategori',
  _ElemId.diagram:  'Diagram Progress',
  _ElemId.stats:    'Statistik',
  _ElemId.branding: 'Watermark',
};

List<_Elem> _defaultElems() => [
  _Elem(id: _ElemId.title,    x: 50, y: 16, fontSize: 24),
  _Elem(id: _ElemId.diagram,  x: 50, y: 44, fontSize: 14),
  _Elem(id: _ElemId.stats,    x: 50, y: 74, fontSize: 13),
  _Elem(id: _ElemId.branding, x: 50, y: 90, fontSize: 11),
];

// ─── Donut chart painter ──────────────────────────────────────────────────────

class _DonutPainter extends CustomPainter {
  final double progress;
  _DonutPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = size.width * 0.34;
    final sw = r * 0.32;

    canvas.drawCircle(
      Offset(cx, cy), r,
      Paint()
        ..color = Colors.white.withAlpha(56)
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw
        ..strokeCap = StrokeCap.round,
    );

    final sweep = 2 * 3.14159265 * (progress.clamp(0, 100) / 100);
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      -1.5707963, // -π/2 (top)
      sweep,
      false,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw
        ..strokeCap = StrokeCap.round,
    );

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
  bool shouldRepaint(_DonutPainter old) => old.progress != progress;
}

// ─── Arc chart painter ────────────────────────────────────────────────────────

class _ArcPainter extends CustomPainter {
  final double progress;
  _ArcPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.72;
    final r  = size.width * 0.37;
    final sw = r * 0.24;

    final bgPaint = Paint()
      ..color = Colors.white.withAlpha(56)
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      3.14159265, // π (left side)
      3.14159265, // sweep π (half circle)
      false,
      bgPaint,
    );

    final sweep = 3.14159265 * (progress.clamp(0, 100) / 100);
    if (sweep > 0.01) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        3.14159265,
        sweep,
        false,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = sw
          ..strokeCap = StrokeCap.round,
      );
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
  bool shouldRepaint(_ArcPainter old) => old.progress != progress;
}

// ─── Main snapshot sheet ──────────────────────────────────────────────────────

class SnapshotSheet extends ConsumerStatefulWidget {
  final Habit habit;
  const SnapshotSheet({super.key, required this.habit});

  @override
  ConsumerState<SnapshotSheet> createState() => _SnapshotSheetState();
}

class _SnapshotSheetState extends ConsumerState<SnapshotSheet> {
  final _previewKey = GlobalKey();
  late List<_Elem> _elems;
  _ElemId? _selectedId;
  bool _arcMode = false;
  File? _bgImage;
  bool _exporting = false;

  // Background zoom/pan
  double _bgScale = 1.0;
  double _bgScaleStart = 1.0;
  Offset _bgOffset = Offset.zero;

  static const double _prevW = 220;
  static const double _prevH = 390;

  @override
  void initState() {
    super.initState();
    _elems = _defaultElems();
  }

  _Elem? get _selected =>
      _selectedId == null ? null : _elems.firstWhere((e) => e.id == _selectedId!);

  // ─── Image picking ──────────────────────────────────────────────────────────

  Future<void> _pickImage(ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source, imageQuality: 85);
    if (picked != null && mounted) {
      setState(() {
        _bgImage = File(picked.path);
        _bgScale = 1.0;
        _bgOffset = Offset.zero;
      });
    }
  }

  // ─── Capture ────────────────────────────────────────────────────────────────

  Future<Uint8List?> _capture() async {
    await Future.delayed(const Duration(milliseconds: 80));
    try {
      final boundary = _previewKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  Future<File?> _captureToFile() async {
    final bytes = await _capture();
    if (bytes == null) return null;
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/habit-snapshot-${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(bytes);
    return file;
  }

  // ─── Actions ────────────────────────────────────────────────────────────────

  Future<void> _handleShare() async {
    setState(() => _exporting = true);
    try {
      final file = await _captureToFile();
      if (file == null) return;
      await Share.shareXFiles(
        [XFile(file.path)],
        text: '${widget.habit.title} — ${widget.habit.progressPercent.toStringAsFixed(0)}% Progress 🌿 HabitTracker',
      );
    } catch (_) {
      // Ignore share cancellation
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _handlePostToFeed() async {
    setState(() => _exporting = true);
    try {
      final file = await _captureToFile();
      if (file == null || !mounted) return;
      // Return file to parent — parent will open PostFormSheet with it pre-loaded
      Navigator.of(context).pop(file);
    } catch (_) {
      if (mounted) setState(() => _exporting = false);
    }
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
            child: Row(
              children: [
                const Icon(Icons.camera_alt_outlined, size: 16, color: AppColors.ink),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Buat Snapshot',
                          style: GoogleFonts.syne(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink)),
                      Text('Drag elemen untuk memindahkan • Ketuk untuk memilih & ubah ukuran',
                          style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.muted)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 20),
                  color: AppColors.muted,
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                children: [
                  // Preview card
                  Center(child: _buildPreview()),
                  const SizedBox(height: 16),
                  // Controls
                  _buildBgSection(),
                  const SizedBox(height: 10),
                  _buildDiagramSection(),
                  const SizedBox(height: 10),
                  _buildSelectedSection(),
                  const SizedBox(height: 10),
                  _buildAllElemsSection(),
                  const SizedBox(height: 16),
                  // Actions
                  _buildShareButton(),
                  const SizedBox(height: 8),
                  _buildPostButton(),
                  SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Preview card ────────────────────────────────────────────────────────────

  Widget _buildPreview() {
    return GestureDetector(
      // 2-finger pinch = zoom background; 1-finger on empty area = pan background
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
                // Base background
                Positioned.fill(
                  child: Container(color: const Color(0xFF0f2018)),
                ),
                // User photo with zoom/pan transform
                if (_bgImage != null)
                  Positioned.fill(
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..translate(_bgOffset.dx, _bgOffset.dy)
                        ..scale(_bgScale),
                      child: Image.file(_bgImage!, fit: BoxFit.cover,
                          width: _prevW, height: _prevH),
                    ),
                  ),
                // Gradient overlay
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: _bgImage != null
                            ? [const Color(0x47000000), const Color(0x9E000000)]
                            : [const Color(0x8C2B59FF), const Color(0x5910B981)],
                      ),
                    ),
                  ),
                ),
                // Hint when no image
                if (_bgImage == null)
                  const Positioned.fill(
                    child: Center(
                      child: Text(
                        'Pilih foto latar\ndari panel bawah',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0x66FFFFFF), fontSize: 12),
                      ),
                    ),
                  ),
                // Draggable elements
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
      top:  el.y / 100 * _prevH,
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
    switch (el.id) {
      case _ElemId.title:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.habit.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: fs, fontWeight: FontWeight.w800, color: Colors.white,
                shadows: const [Shadow(color: Colors.black54, blurRadius: 8)],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              widget.habit.categoryDisplay,
              style: TextStyle(
                fontSize: fs * 0.55, color: Colors.white.withAlpha(204),
                shadows: const [Shadow(color: Colors.black38, blurRadius: 4)],
              ),
            ),
          ],
        );

      case _ElemId.diagram:
        final size = fs * 8;
        return _arcMode
            ? CustomPaint(size: Size(size, size * 0.78), painter: _ArcPainter(widget.habit.progressPercent))
            : CustomPaint(size: Size(size, size), painter: _DonutPainter(widget.habit.progressPercent));

      case _ElemId.stats:
        final items = [
          ('🔥', '${widget.habit.currentStreak}', 'Streak'),
          ('✅', '${widget.habit.totalCompletedDays}', 'Selesai'),
          ('🏆', '${widget.habit.longestStreak}', 'Longest'),
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
            fontSize: fs, color: Colors.white.withAlpha(166),
            shadows: const [Shadow(color: Colors.black26, blurRadius: 3)],
          ),
        );
    }
  }

  // ─── Control sections ────────────────────────────────────────────────────────

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
                onPressed: () => _pickImage(ImageSource.gallery),
                icon: const Icon(Icons.folder_open_outlined, size: 14),
                label: Text(_bgImage != null ? 'Galeri' : 'Pilih Galeri',
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
                onPressed: () => _pickImage(ImageSource.camera),
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
          if (_bgImage != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => setState(() {
                  _bgImage = null;
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
        Expanded(child: _DiagramBtn(label: 'Donut', icon: Icons.circle_outlined, selected: !_arcMode, onTap: () => setState(() => _arcMode = false))),
        const SizedBox(width: 8),
        Expanded(child: _DiagramBtn(label: 'Arc', icon: Icons.nights_stay_outlined, selected: _arcMode, onTap: () => setState(() => _arcMode = true))),
      ]),
    );
  }

  Widget _buildSelectedSection() {
    final sel = _selected;
    return _sectionCard(
      label: 'ELEMEN TERPILIH',
      icon: Icons.gps_fixed_outlined,
      child: sel == null
          ? Text('Klik elemen di preview untuk memilihnya.',
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

  Widget _buildShareButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _exporting ? null : _handleShare,
        icon: _exporting
            ? const SizedBox(width: 14, height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.download_rounded, size: 16),
        label: Text(_exporting ? 'Membuat gambar...' : 'Download / Share',
            style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildPostButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _exporting ? null : _handlePostToFeed,
        icon: const Icon(Icons.send_rounded, size: 15),
        label: Text('Post ke Feed',
            style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700)),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

// ─── Helper widgets ───────────────────────────────────────────────────────────

class _DiagramBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _DiagramBtn({required this.label, required this.icon, required this.selected, required this.onTap});

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
