import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HabitTrackerApp());
}

// ── Model ──────────────────────────────────────────────────────────────────────

class HabitEntry {
  final String date; // format: 'yyyy-MM-dd'
  bool isDone;

  HabitEntry({required this.date, this.isDone = false});

  factory HabitEntry.fromJson(Map<String, dynamic> j) =>
      HabitEntry(date: j['date'], isDone: j['isDone'] ?? false);

  Map<String, dynamic> toJson() => {'date': date, 'isDone': isDone};
}

class Habit {
  final String id;
  String name;
  // Menyimpan status per tanggal: { 'yyyy-MM-dd': isDone }
  List<HabitEntry> entries;

  Habit({required this.id, required this.name, List<HabitEntry>? entries})
      : entries = entries ?? [];

  bool isDoneOn(String date) =>
      entries.any((e) => e.date == date && e.isDone);

  void toggleOn(String date) {
    final idx = entries.indexWhere((e) => e.date == date);
    if (idx >= 0) {
      entries[idx].isDone = !entries[idx].isDone;
    } else {
      entries.add(HabitEntry(date: date, isDone: true));
    }
  }

  factory Habit.fromJson(Map<String, dynamic> j) => Habit(
        id: j['id'],
        name: j['name'],
        entries: (j['entries'] as List<dynamic>? ?? [])
            .map((e) => HabitEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'entries': entries.map((e) => e.toJson()).toList(),
      };
}

// ── Storage helper ─────────────────────────────────────────────────────────────

class HabitStorage {
  static const _key = 'habits_v2';

  static Future<List<Habit>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return _defaultHabits();
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => Habit.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<void> save(List<Habit> habits) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(habits.map((h) => h.toJson()).toList()));
  }

  static List<Habit> _defaultHabits() => [
        Habit(id: '1', name: 'Minum 8 gelas air'),
        Habit(id: '2', name: 'Olahraga 30 menit'),
        Habit(id: '3', name: 'Membaca buku'),
      ];
}

// ── App ────────────────────────────────────────────────────────────────────────

class HabitTrackerApp extends StatelessWidget {
  const HabitTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Habit Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C63FF),
          brightness: Brightness.light,
        ),
        fontFamily: 'Poppins',
      ),
      home: const HabitHomePage(),
    );
  }
}

// ── Home Page ──────────────────────────────────────────────────────────────────

class HabitHomePage extends StatefulWidget {
  const HabitHomePage({super.key});

  @override
  State<HabitHomePage> createState() => _HabitHomePageState();
}

class _HabitHomePageState extends State<HabitHomePage>
    with SingleTickerProviderStateMixin {
  static const Color _primary   = Color(0xFF6C63FF);
  static const Color _surface   = Color(0xFFF5F4FF);
  static const Color _cardBg    = Colors.white;
  static const Color _textDark  = Color(0xFF1E1B4B);
  static const Color _textLight = Color(0xFF7C7A99);

  List<Habit> _habits = [];
  bool _loading = true;
  DateTime _selectedDate = DateTime.now();

  late AnimationController _fabController;
  // Disimpan di didChangeDependencies agar aman dipakai setelah setState
  ScaffoldMessengerState? _messenger;

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _loadHabits();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _messenger = ScaffoldMessenger.of(context);
  }

  @override
  void dispose() {
    _fabController.dispose();
    super.dispose();
  }

  // ── Persistence ──
  Future<void> _loadHabits() async {
    final habits = await HabitStorage.load();
    if (mounted) setState(() { _habits = habits; _loading = false; });
  }

  Future<void> _saveHabits() => HabitStorage.save(_habits);

  // ── Tanggal helper ──
  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String get _selectedKey => _dateKey(_selectedDate);

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  // ── Tambah habit ──
  void _showAddHabitDialog() {
    final controller = TextEditingController();
    _fabController.forward().then((_) => _fabController.reverse());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Tambah Habit Baru',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w700,
            color: _textDark,
            fontSize: 18,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          cursorColor: _primary,
          style: const TextStyle(fontFamily: 'Poppins', color: _textDark),
          decoration: InputDecoration(
            hintText: 'Contoh: Meditasi 10 menit',
            hintStyle: const TextStyle(
                fontFamily: 'Poppins', color: _textLight, fontSize: 14),
            filled: true,
            fillColor: _surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _primary, width: 2),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          onSubmitted: (_) => _addHabit(controller.text, ctx),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal',
                style: TextStyle(
                    fontFamily: 'Poppins', color: _textLight, fontSize: 14)),
          ),
          ElevatedButton(
            onPressed: () => _addHabit(controller.text, ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text('Tambah',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    fontSize: 14)),
          ),
        ],
      ),
    );
  }

  void _addHabit(String name, BuildContext ctx) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      _habits.add(Habit(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: trimmed,
      ));
    });
    _saveHabits();
    Navigator.pop(ctx);
  }

  // ── Toggle pada tanggal terpilih ──
  void _toggleHabit(String id) {
    setState(() {
      _habits.firstWhere((h) => h.id == id).toggleOn(_selectedKey);
    });
    _saveHabits();
  }

  // ── Hapus habit ──
  void _removeHabit(String id) {
    final habit = _habits.firstWhere((h) => h.id == id);
    setState(() => _habits.removeWhere((h) => h.id == id));
    _saveHabits();

    _messenger
      ?..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            '"${habit.name}" dihapus',
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 13),
          ),
          backgroundColor: const Color(0xFF1E1B4B),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'Batalkan',
            textColor: const Color(0xFFB5B1FF),
            onPressed: () {
              setState(() => _habits.add(habit));
              _saveHabits();
            },
          ),
        ),
      );
  }

  // ── Pilih tanggal ──
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: _primary,
            onPrimary: Colors.white,
            surface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  // ── Progress untuk tanggal terpilih ──
  int get _doneCount =>
      _habits.where((h) => h.isDoneOn(_selectedKey)).length;
  double get _progress =>
      _habits.isEmpty ? 0 : _doneCount / _habits.length;

  String _formattedDate(DateTime d) {
    const days = ['Senin','Selasa','Rabu','Kamis','Jumat','Sabtu','Minggu'];
    const months = [
      'Januari','Februari','Maret','April','Mei','Juni',
      'Juli','Agustus','September','Oktober','November','Desember'
    ];
    return '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF5F4FF),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _surface,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Baris tanggal + tombol filter ──
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _formattedDate(_selectedDate),
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              color: _textLight,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: _pickDate,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: _isToday(_selectedDate)
                                  ? const Color(0xFFEEECFF)
                                  : const Color(0xFFFFE8D6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.calendar_today_rounded,
                                  size: 12,
                                  color: _isToday(_selectedDate)
                                      ? _primary
                                      : const Color(0xFFE07B3A),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _isToday(_selectedDate)
                                      ? 'Hari ini'
                                      : 'Ganti tanggal',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: _isToday(_selectedDate)
                                        ? _primary
                                        : const Color(0xFFE07B3A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Kebiasaanku 🌱',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: _textDark,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _ProgressCard(
                      doneCount: _doneCount,
                      total: _habits.length,
                      progress: _progress,
                      isToday: _isToday(_selectedDate),
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      'Daftar Habit',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _textDark,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),

            _habits.isEmpty
                ? SliverToBoxAdapter(child: _buildEmptyState())
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final habit = _habits[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 5),
                          child: _HabitCard(
                            habit: habit,
                            isDone: habit.isDoneOn(_selectedKey),
                            onToggle: () => _toggleHabit(habit.id),
                            onDelete: () => _removeHabit(habit.id),
                          ),
                        );
                      },
                      childCount: _habits.length,
                    ),
                  ),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),

      floatingActionButton: ScaleTransition(
        scale: Tween<double>(begin: 1.0, end: 0.88).animate(
          CurvedAnimation(parent: _fabController, curve: Curves.easeOut),
        ),
        child: FloatingActionButton.extended(
          onPressed: _showAddHabitDialog,
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          elevation: 4,
          icon: const Icon(Icons.add_rounded, size: 22),
          label: const Text(
            'Tambah Habit',
            style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                fontSize: 14),
          ),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFEEECFF),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.emoji_nature_rounded,
                size: 40, color: _primary),
          ),
          const SizedBox(height: 16),
          const Text(
            'Belum ada habit nih!',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w700,
              fontSize: 17,
              color: _textDark,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Yuk mulai tambahkan kebiasaan\npositif pertamamu ✨',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              color: _textLight,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Progress Card ──────────────────────────────────────────────────────────────

class _ProgressCard extends StatelessWidget {
  final int doneCount;
  final int total;
  final double progress;
  final bool isToday;

  const _ProgressCard({
    required this.doneCount,
    required this.total,
    required this.progress,
    required this.isToday,
  });

  String get _motivationText {
    if (total == 0) return 'Ayo mulai hari ini! 💪';
    if (progress == 0) return isToday ? 'Semangat, kamu pasti bisa! 💪' : 'Tidak ada yang selesai 😴';
    if (progress < 0.5) return isToday ? 'Terus lanjutkan! 🔥' : 'Kurang dari setengah nih 🙁';
    if (progress < 1.0) return isToday ? 'Hampir selesai, hebat! ⚡' : 'Hampir semua selesai! 👏';
    return 'Semua selesai! Luar biasa! 🎉';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFF9B8FFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isToday ? 'Progress Hari Ini' : 'Progress Hari Itu',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '$doneCount / $total',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 8,
                backgroundColor: Colors.white24,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _motivationText,
            style: const TextStyle(
              fontFamily: 'Poppins',
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Habit Card ─────────────────────────────────────────────────────────────────

class _HabitCard extends StatelessWidget {
  final Habit habit;
  final bool isDone;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _HabitCard({
    required this.habit,
    required this.isDone,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDone ? const Color(0xFFF0FFF9) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDone
              ? const Color(0xFF43C59E).withOpacity(0.5)
              : const Color(0xFFE8E6FF),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isDone
                ? const Color(0xFF43C59E).withOpacity(0.08)
                : Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onToggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color:
                    isDone ? const Color(0xFF43C59E) : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDone
                      ? const Color(0xFF43C59E)
                      : const Color(0xFFCBC8FF),
                  width: 2,
                ),
              ),
              child: isDone
                  ? const Icon(Icons.check_rounded,
                      color: Colors.white, size: 16)
                  : null,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              habit.name,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDone
                    ? const Color(0xFF43C59E)
                    : const Color(0xFF1E1B4B),
                decoration: isDone ? TextDecoration.lineThrough : null,
                decorationColor: const Color(0xFF43C59E),
              ),
            ),
          ),
          GestureDetector(
            onTap: onDelete,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F4FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.close_rounded,
                size: 16,
                color: Color(0xFF9B8FFF),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
