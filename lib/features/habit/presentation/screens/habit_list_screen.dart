import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../domain/habit_model.dart';
import '../providers/habit_provider.dart';
import '../widgets/habit_card.dart';
import 'habit_form_screen.dart';

const _fSemua = 'semua';
const _fBelum = 'belum_selesai';
const _fHariIni = 'selesai_hari_ini';
const _fSelesai = 'selesai';

class HabitListScreen extends ConsumerStatefulWidget {
  const HabitListScreen({super.key});

  @override
  ConsumerState<HabitListScreen> createState() => _HabitListScreenState();
}

class _HabitListScreenState extends ConsumerState<HabitListScreen> {
  String _filter = _fSemua;
  String _search = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Habit> _applyFilters(List<Habit> habits) {
    var result = habits;
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      result = result.where((h) => h.title.toLowerCase().contains(q)).toList();
    }
    if (_filter == _fBelum) return result.where((h) => !h.isComplete).toList();
    if (_filter == _fHariIni) return result.where((h) => h.checkedToday).toList();
    if (_filter == _fSelesai) return result.where((h) => h.isComplete).toList();
    return result;
  }

  Map<String, int> _counts(List<Habit> habits) {
    final searched = _search.isNotEmpty
        ? habits.where((h) => h.title.toLowerCase().contains(_search.toLowerCase())).toList()
        : habits;
    return {
      _fSemua: searched.length,
      _fBelum: searched.where((h) => !h.isComplete).length,
      _fHariIni: searched.where((h) => h.checkedToday).length,
      _fSelesai: searched.where((h) => h.isComplete).length,
    };
  }

  void _openForm(BuildContext context, {Habit? habit}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => HabitFormSheet(habit: habit, ref: ref),
    );
  }

  void _confirmDelete(BuildContext context, int id, String title) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Hapus habit?', style: GoogleFonts.syne(fontWeight: FontWeight.w700)),
        content: Text('"$title" akan dihapus permanen.', style: GoogleFonts.dmSans()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(habitListProvider.notifier).deleteHabit(id);
            },
            child: const Text('Hapus', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final habitsAsync = ref.watch(habitListProvider);
    final allHabits = habitsAsync.valueOrNull ?? [];
    final filtered = _applyFilters(allHabits);
    final counts = _counts(allHabits);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Row(children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.checklist_rounded, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 8),
          Text('Kelola Habit',
            style: GoogleFonts.syne(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink)),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary),
            onPressed: () => _openForm(context),
          ),
        ],
      ),
      body: habitsAsync.when(
        loading: () => const LoadingWidget(),
        error: (_, __) => ErrorWidget2(
          message: 'Gagal memuat habit',
          onRetry: () => ref.read(habitListProvider.notifier).load(),
        ),
        data: (_) {
          if (allHabits.isEmpty) return _EmptyState(onAdd: () => _openForm(context));
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () => ref.read(habitListProvider.notifier).load(),
            child: CustomScrollView(
              slivers: [
                // Search bar
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (v) => setState(() => _search = v),
                        style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.ink),
                        decoration: InputDecoration(
                          hintText: 'Cari habit...',
                          hintStyle: GoogleFonts.dmSans(fontSize: 14, color: AppColors.muted),
                          prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.muted),
                          suffixIcon: _search.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.muted),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    setState(() => _search = '');
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),
                ),

                // Filter tabs
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _FilterTab(
                            label: 'Semua',
                            count: counts[_fSemua]!,
                            active: _filter == _fSemua,
                            onTap: () => setState(() => _filter = _fSemua),
                          ),
                          const SizedBox(width: 8),
                          _FilterTab(
                            label: 'Belum Selesai',
                            count: counts[_fBelum]!,
                            active: _filter == _fBelum,
                            onTap: () => setState(() => _filter = _fBelum),
                          ),
                          const SizedBox(width: 8),
                          _FilterTab(
                            label: 'Selesai Hari Ini',
                            count: counts[_fHariIni]!,
                            active: _filter == _fHariIni,
                            onTap: () => setState(() => _filter = _fHariIni),
                          ),
                          const SizedBox(width: 8),
                          _FilterTab(
                            label: 'Selesai',
                            count: counts[_fSelesai]!,
                            active: _filter == _fSelesai,
                            onTap: () => setState(() => _filter = _fSelesai),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Result count hint
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${filtered.length} habit ditemukan',
                          style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.muted),
                        ),
                        if (_search.isNotEmpty || _filter != _fSemua)
                          GestureDetector(
                            onTap: () {
                              _searchCtrl.clear();
                              setState(() { _search = ''; _filter = _fSemua; });
                            },
                            child: Text(
                              'Reset filter',
                              style: GoogleFonts.dmSans(
                                fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // Habit list or empty result
                if (filtered.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Container(
                          width: 60, height: 60,
                          decoration: BoxDecoration(
                            color: AppColors.primaryLighter,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.search_off_rounded, size: 28, color: AppColors.primary),
                        ),
                        const SizedBox(height: 12),
                        Text('Tidak ada habit',
                          style: GoogleFonts.syne(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink)),
                        const SizedBox(height: 4),
                        Text('Coba ubah filter atau kata kunci pencarian',
                          style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.muted)),
                      ]),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 100),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: HabitCard(
                            habit: filtered[i],
                            onToggle: () => ref.read(habitListProvider.notifier)
                                .toggleCheck(filtered[i].idHabit),
                            onEdit: () => _openForm(context, habit: filtered[i]),
                            onDelete: () =>
                                _confirmDelete(context, filtered[i].idHabit, filtered[i].title),
                            onDetail: () => context.push('/habit-detail/${filtered[i].idHabit}'),
                          ),
                        ),
                        childCount: filtered.length,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(context),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }
}

// ── Filter Tab ─────────────────────────────────────────────────────────────────
class _FilterTab extends StatelessWidget {
  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;

  const _FilterTab({
    required this.label,
    required this.count,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: active ? AppColors.primaryLight : AppColors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active ? AppColors.primary : AppColors.border,
              width: active ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active ? AppColors.primary : AppColors.muted,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: active ? AppColors.primary : AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: active ? Colors.white : AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

// ── Empty State ────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: AppColors.primaryLighter,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.eco_rounded, size: 36, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text('Belum ada habit',
            style: GoogleFonts.syne(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.ink)),
          const SizedBox(height: 6),
          Text('Mulai buat habit pertamamu!',
            style: GoogleFonts.dmSans(color: AppColors.muted)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Tambah Habit'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
          ),
        ]),
      );
}
