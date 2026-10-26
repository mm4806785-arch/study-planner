import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const App());

const extraName = 'إضافي';
final ValueNotifier<ThemeMode> appThemeMode = ValueNotifier(ThemeMode.light);

bool get isDark => appThemeMode.value == ThemeMode.dark;
Color get bg => isDark ? const Color(0xFFE8EDE8) : const Color(0xFF28352D);
Color get deep => isDark ? const Color(0xFF101713) : const Color(0xFF26392E);
Color get cream => isDark ? const Color(0xFF202923) : const Color(0xFFFAF8F2);
Color get sage => isDark ? const Color(0xFFA4BEA8) : const Color(0xFF62816B);
Color get brown => isDark ? const Color(0xFFC8B99F) : const Color(0xFF78664F);
Color get leafGreen =>
    isDark ? const Color(0xFF70977A) : const Color(0xFF66866D);
Color get onAccent => const Color(0xFFFAF8F2);
Color get navForeground => isDark ? bg : onAccent;

class Subject {
  String id, name, label;
  int total, done;
  DateTime exam;
  Subject(this.id, this.name, this.total, this.done, this.exam, this.label);
  Map<String, dynamic> toJson() => {
    'i': id,
    'n': name,
    't': total,
    'd': done,
    'e': exam.millisecondsSinceEpoch,
    'l': label,
  };
  factory Subject.fromJson(Map<String, dynamic> j) => Subject(
    j['i'],
    j['n'],
    j['t'],
    j['d'],
    DateTime.fromMillisecondsSinceEpoch(j['e']),
    j['l'] ?? 'شابتر',
  );
}

class Task {
  String id, date, subject, title;
  int mins;
  bool done;
  Task(
    this.id,
    this.date,
    this.subject,
    this.title,
    this.mins, [
    this.done = false,
  ]);
  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date,
    's': subject,
    't': title,
    'm': mins,
    'd': done,
  };
  factory Task.fromJson(Map<String, dynamic> j) =>
      Task(j['id'], j['date'], j['s'], j['t'], j['m'], j['d'] ?? false);
}

String ymd(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

const weekdaysAr = [
  'الإثنين',
  'الثلاثاء',
  'الأربعاء',
  'الخميس',
  'الجمعة',
  'السبت',
  'الأحد',
];

String dayName(String ymdStr) {
  final d = DateTime.tryParse(ymdStr);
  return d == null ? '' : weekdaysAr[d.weekday - 1];
}

String examLabel(DateTime e) {
  final d = dayOnly(e).difference(dayOnly(DateTime.now())).inDays;
  if (d < 0) return 'الامتحان عدّى';
  if (d == 0) return 'الامتحان النهارده';
  if (d == 1) return 'الامتحان بكرة';
  return 'الامتحان بعد $d يوم';
}

class PlanResult {
  final List<Task> tasks;
  final int overflow;
  PlanResult(this.tasks, this.overflow);
}

PlanResult generate(List<Subject> subs, double hours, int minsPer) {
  final start = dayOnly(DateTime.now());
  final cap = (hours * 60 / minsPer).floor().clamp(1, 50).toInt();
  final rem = <String, int>{};
  final next = <String, int>{};
  final dl = <String, int>{};
  var horizon = 1;
  for (final s in subs) {
    rem[s.id] = (s.total - s.done).clamp(0, 1000).toInt();
    next[s.id] = s.done + 1;
    var d = dayOnly(s.exam).difference(start).inDays;
    if (d < 1) d = 1;
    if (d > 120) d = 120;
    dl[s.id] = d;
    if (d > horizon) horizon = d;
  }
  final tasks = <Task>[];
  var n = 0;
  var overflow = 0;
  Task mk(int day, Subject s) {
    final dt = DateTime(start.year, start.month, start.day + day);
    final k = next[s.id]!;
    next[s.id] = k + 1;
    rem[s.id] = rem[s.id]! - 1;
    return Task('t${n++}', ymd(dt), s.name, '${s.label} $k', minsPer);
  }

  for (var day = 0; day < horizon; day++) {
    for (var slot = 0; slot < cap; slot++) {
      Subject? best;
      var bu = -1.0;
      for (final s in subs) {
        if (rem[s.id]! <= 0 || day >= dl[s.id]!) continue;
        final u = rem[s.id]! / (dl[s.id]! - day);
        if (u > bu) {
          bu = u;
          best = s;
        }
      }
      if (best == null) break;
      tasks.add(mk(day, best));
    }
  }
  for (final s in subs) {
    while (rem[s.id]! > 0) {
      tasks.add(mk(dl[s.id]! - 1, s));
      overflow++;
    }
  }
  tasks.sort((a, b) => a.date.compareTo(b.date));
  return PlanResult(tasks, overflow);
}

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<ThemeMode>(
    valueListenable: appThemeMode,
    builder: (context, mode, _) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'مساحتك الأكاديمية',
        themeMode: mode,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: canvasColorFor(false),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF66866D),
            brightness: Brightness.light,
          ),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: canvasColorFor(true),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF8FAF96),
            brightness: Brightness.dark,
          ),
        ),
        builder: (c, w) =>
            Directionality(textDirection: TextDirection.rtl, child: w!),
        home: const Home(),
      );
    },
  );
}

Color canvasColorFor(bool dark) =>
    dark ? const Color(0xFF171F1A) : const Color(0xFFF5F4EE);

class LeafBranch extends StatefulWidget {
  const LeafBranch({super.key});
  @override
  State<LeafBranch> createState() => _LeafBranchState();
}

class _LeafBranchState extends State<LeafBranch>
    with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
  )..repeat();
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedBuilder(
      animation: c,
      builder: (_, __) => CustomPaint(
        size: const Size(230, 280),
        painter: BranchPainter(c.value),
      ),
    ),
  );
}

class BranchPainter extends CustomPainter {
  final double t;
  BranchPainter(this.t);
  Offset quad(Offset a, Offset b, Offset c, double u) => Offset(
    (1 - u) * (1 - u) * a.dx + 2 * (1 - u) * u * b.dx + u * u * c.dx,
    (1 - u) * (1 - u) * a.dy + 2 * (1 - u) * u * b.dy + u * u * c.dy,
  );

  void leaf(Canvas c, Offset o, double ang, double len, double op) {
    c.save();
    c.translate(o.dx, o.dy);
    c.rotate(ang);
    final p = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(len * 0.5, -len * 0.38, len, 0)
      ..quadraticBezierTo(len * 0.5, len * 0.38, 0, 0);
    c.drawPath(p, Paint()..color = sage.withOpacity(op));
    c.drawLine(
      Offset.zero,
      Offset(len, 0),
      Paint()
        ..color = sage.withOpacity(0.45)
        ..strokeWidth = 1,
    );
    c.restore();
  }

  @override
  void paint(Canvas canvas, Size s) {
    final w = sin(t * 2 * pi);
    const p0 = Offset(-10, -10);
    final p1 = Offset(55 + 10 * w, 90);
    final p2 = Offset(125 + 16 * w, 240);
    canvas.drawPath(
      Path()
        ..moveTo(p0.dx, p0.dy)
        ..quadraticBezierTo(p1.dx, p1.dy, p2.dx, p2.dy),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = sage.withOpacity(0.5),
    );
    for (var i = 1; i <= 9; i++) {
      final pt = quad(p0, p1, p2, i / 10);
      final side = i.isEven ? 1.0 : -1.0;
      final sway = sin(t * 2 * pi + i * 0.7) * 0.2;
      leaf(
        canvas,
        pt,
        pi / 2 + side * 0.95 + sway,
        40 - i * 1.6,
        0.2 + (i % 3) * 0.07,
      );
    }
    leaf(canvas, p2, pi / 2 + w * 0.15, 30, 0.3);
  }

  @override
  bool shouldRepaint(BranchPainter old) => old.t != t;
}

class Breathe extends StatefulWidget {
  final Widget child;
  const Breathe({super.key, required this.child});
  @override
  State<Breathe> createState() => _BreatheState();
}

class _BreatheState extends State<Breathe> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat(reverse: true);
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(
    scale: Tween(
      begin: 1.0,
      end: 1.08,
    ).animate(CurvedAnimation(parent: c, curve: Curves.easeInOut)),
    child: widget.child,
  );
}

Widget stepper(
  String title,
  int v,
  void Function(int) on, {
  int min = 0,
  int max = 500,
}) => Row(
  children: [
    Expanded(
      child: Text(title, style: TextStyle(fontSize: 18, color: bg)),
    ),
    IconButton(
      onPressed: v > min ? () => on(v - 1) : null,
      icon: Icon(Icons.remove_circle_outline, color: brown),
    ),
    SizedBox(
      width: 36,
      child: Text(
        '$v',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 20, color: bg, fontWeight: FontWeight.bold),
      ),
    ),
    IconButton(
      onPressed: v < max ? () => on(v + 1) : null,
      icon: Icon(Icons.add_circle_outline, color: leafGreen),
    ),
  ],
);

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int tab = 0;
  double hours = 4;
  int minsPer = 60;
  int overflow = 0;
  List<Subject> subjects = [];
  List<Task> tasks = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    appThemeMode.value = p.getBool('darkMode') == true
        ? ThemeMode.dark
        : ThemeMode.light;
    setState(() {
      hours = p.getDouble('hours') ?? 4;
      minsPer = p.getInt('minsPer') ?? 60;
      overflow = p.getInt('overflow') ?? 0;
      try {
        final s = p.getString('subjects');
        if (s != null) {
          subjects = (jsonDecode(s) as List)
              .map((j) => Subject.fromJson(j))
              .toList();
        }
        final t = p.getString('tasks');
        if (t != null) {
          tasks = (jsonDecode(t) as List).map((j) => Task.fromJson(j)).toList();
        }
      } catch (_) {
        subjects = [];
        tasks = [];
      }
      if (subjects.isEmpty) tab = 3;
    });
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
      'tasks',
      jsonEncode(tasks.map((t) => t.toJson()).toList()),
    );
    await p.setString(
      'subjects',
      jsonEncode(subjects.map((s) => s.toJson()).toList()),
    );
    await p.setDouble('hours', hours);
    await p.setInt('minsPer', minsPer);
    await p.setInt('overflow', overflow);
  }

  Future<void> toggleTheme() async {
    final next = isDark ? ThemeMode.light : ThemeMode.dark;
    appThemeMode.value = next;
    final p = await SharedPreferences.getInstance();
    await p.setBool('darkMode', next == ThemeMode.dark);
  }

  void snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  int doneOf(Subject s) =>
      (s.done + tasks.where((t) => t.subject == s.name && t.done).length)
          .clamp(0, s.total)
          .toInt();

  void removeTask(Task t) {
    final i = tasks.indexOf(t);
    if (i < 0) return;
    setState(() => tasks.removeAt(i));
    save();
    final m = ScaffoldMessenger.of(context);
    m.hideCurrentSnackBar();
    m.showSnackBar(
      SnackBar(
        content: const Text('اتحذفت المهمة'),
        action: SnackBarAction(
          label: 'تراجع',
          onPressed: () {
            setState(() => tasks.insert(i.clamp(0, tasks.length).toInt(), t));
            save();
          },
        ),
      ),
    );
  }

  Widget row(Task t) => InkWell(
    onLongPress: () => removeTask(t),
    onTap: () {
      setState(() => t.done = !t.done);
      save();
    },
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
      child: Row(
        children: [
          Icon(
            t.done ? Icons.check_circle : Icons.circle_outlined,
            color: t.done ? leafGreen : brown,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${t.subject} — ${t.title}',
              style: TextStyle(
                fontSize: 18,
                color: bg,
                decoration: t.done ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: bg.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('${t.mins} د', style: TextStyle(color: bg)),
          ),
        ],
      ),
    ),
  );

  Widget paper(List<Widget> kids) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: cream,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: kids),
  );

  Widget warn() => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: brown.withOpacity(0.25),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Text(
      'فيه $overflow مهمة زيادة عن وقتك قبل الامتحان. زوّد ساعات المذاكرة أو قلّل مدة المهمة من «إعداد».',
      style: TextStyle(color: bg, fontSize: 16),
    ),
  );

  Widget home() {
    final n = dayOnly(DateTime.now());
    final list = tasks.where((t) => t.date == ymd(n)).toList();
    final completedUnits = subjects.fold<int>(
      0,
      (sum, subject) => sum + doneOf(subject),
    );
    final totalUnits = subjects.fold<int>(
      0,
      (sum, subject) => sum + subject.total,
    );
    final progress = totalUnits == 0 ? 0.0 : completedUnits / totalUnits;
    int? left;
    var allPast = false;
    if (subjects.isNotEmpty) {
      final diffs = subjects
          .map((s) => dayOnly(s.exam).difference(n).inDays)
          .toList();
      final upcoming = diffs.where((d) => d >= 0).toList();
      if (upcoming.isEmpty) {
        allPast = true;
        left = -1;
      } else {
        left = upcoming.reduce((a, b) => a < b ? a : b);
      }
    }
    final todayMins = list.fold<int>(0, (a, t) => a + t.mins);
    final todayDoneMins = list
        .where((t) => t.done)
        .fold<int>(0, (a, t) => a + t.mins);
    final sortedSubjects = [...subjects]
      ..sort((a, b) => a.exam.compareTo(b.exam));
    final overdue = tasks
        .where((t) => !t.done && t.date.compareTo(ymd(n)) < 0)
        .toList();
    final screenWidth = MediaQuery.of(context).size.width;
    final cw = screenWidth < 640 ? screenWidth - 40 : (screenWidth - 52) / 2;
    return Stack(
      children: [
        const Positioned(left: -20, top: 0, child: LeafBranch()),
        ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    'مساحتك\nالأكاديمية',
                    style: TextStyle(
                      fontSize: screenWidth < 380 ? 36 : 40,
                      fontWeight: FontWeight.bold,
                      color: bg,
                      height: 1.15,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: isDark
                      ? 'التبديل للوضع الفاتح'
                      : 'التبديل للوضع الداكن',
                  onPressed: toggleTheme,
                  icon: Icon(
                    isDark
                        ? Icons.light_mode_outlined
                        : Icons.dark_mode_outlined,
                  ),
                  style: IconButton.styleFrom(
                    foregroundColor: leafGreen,
                    backgroundColor: cream,
                    padding: const EdgeInsets.all(12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'جلسة دراسة مريحة',
              style: TextStyle(fontSize: 19, color: sage),
            ),
            const SizedBox(height: 12),
            if (left != null)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: sage.withOpacity(0.6)),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    allPast
                        ? 'كل الامتحانات عدّى موعدها'
                        : left == 0
                        ? 'امتحانك النهارده، بالتوفيق!'
                        : 'فاضل $left يوم على أقرب امتحان',
                    style: TextStyle(color: sage),
                  ),
                ),
              ),
            const SizedBox(height: 22),
            if (overflow > 0) warn(),
            paper([
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'تقدّمك الكلي',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: bg,
                      ),
                    ),
                  ),
                  Text(
                    '${(progress * 100).round()}%',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: leafGreen,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 9,
                  color: leafGreen,
                  backgroundColor: leafGreen.withOpacity(0.16),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$completedUnits من $totalUnits وحدة مكتملة',
                style: TextStyle(color: brown, fontSize: 15),
              ),
            ]),
            const SizedBox(height: 16),
            paper([
              Text(
                'جدول الدراسة',
                style: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                  color: bg,
                ),
              ),
              const SizedBox(height: 6),
              if (list.isNotEmpty) ...[
                Text(
                  'خلّصت $todayDoneMins من $todayMins دقيقة النهارده',
                  style: TextStyle(color: brown, fontSize: 15),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: todayMins == 0 ? 0 : todayDoneMins / todayMins,
                    minHeight: 6,
                    color: leafGreen,
                    backgroundColor: leafGreen.withOpacity(0.16),
                  ),
                ),
                const SizedBox(height: 4),
              ],
              if (list.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    subjects.isEmpty
                        ? 'ضيف موادك من تبويب «إعداد» وولّد خطتك'
                        : tasks.isEmpty
                        ? 'دوس «ولّد الخطة» من تبويب «إعداد»'
                        : 'مفيش مهام النهارده',
                    style: TextStyle(color: brown, fontSize: 17),
                  ),
                ),
              ...list.map(row),
            ]),
            if (overdue.isNotEmpty) ...[
              const SizedBox(height: 16),
              paper([
                Text(
                  'مهام متأخرة (${overdue.length})',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                    color: brown,
                  ),
                ),
                const SizedBox(height: 6),
                ...overdue.take(8).map(row),
                if (overdue.length > 8)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'و ${overdue.length - 8} مهمة تانية في تبويب «الخطة»',
                      style: TextStyle(color: brown, fontSize: 15),
                    ),
                  ),
              ]),
            ],
            const SizedBox(height: 26),
            Text(
              'المواد',
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.bold,
                color: bg,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final s in sortedSubjects)
                  Container(
                    width: cw,
                    height: 122,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: leafGreen,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          left: -6,
                          bottom: -6,
                          child: Icon(
                            Icons.eco,
                            size: 54,
                            color: onAccent.withOpacity(0.18),
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: onAccent,
                              ),
                            ),
                            Text(
                              examLabel(s.exam),
                              style: TextStyle(
                                fontSize: 13,
                                color: onAccent.withOpacity(0.85),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${doneOf(s)} / ${s.total}  ·  ${s.total == 0 ? 0 : (doneOf(s) * 100 / s.total).round()}%',
                              style: TextStyle(color: onAccent),
                            ),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(
                              value: s.total == 0 ? 0 : doneOf(s) / s.total,
                              color: onAccent,
                              backgroundColor: onAccent.withOpacity(0.25),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  String planText() {
    final by = <String, List<Task>>{};
    for (final t in tasks) {
      by.putIfAbsent(t.date, () => []).add(t);
    }
    final b = StringBuffer('خطة المذاكرة\n');
    for (final d in (by.keys.toList()..sort())) {
      b.writeln('\n$d');
      for (final t in by[d]!) {
        b.writeln(
          '${t.done ? '✅' : '▫️'} ${t.subject} — ${t.title} (${t.mins} د)',
        );
      }
    }
    return b.toString();
  }

  Widget plan() {
    final by = <String, List<Task>>{};
    for (final t in tasks) {
      by.putIfAbsent(t.date, () => []).add(t);
    }
    final days = by.keys.toList()..sort();
    final todayKey = ymd(DateTime.now());
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            cream,
            isDark ? const Color(0xFF28342C) : const Color(0xFFECE9DF),
          ],
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'خطة المذاكرة',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: bg,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'انسخ الخطة',
                onPressed: tasks.isEmpty
                    ? null
                    : () {
                        Clipboard.setData(ClipboardData(text: planText()));
                        snack('اتنسخت الخطة، الصقها في واتساب');
                      },
                icon: Icon(Icons.copy_all, color: brown),
              ),
            ],
          ),
          if (tasks.isNotEmpty)
            Text(
              'اضغط مطوّلاً على أي مهمة لحذفها',
              style: TextStyle(color: sage, fontSize: 14),
            ),
          if (tasks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'لسه مفيش خطة. ولّدها من تبويب «إعداد».',
                style: TextStyle(color: brown, fontSize: 18),
              ),
            ),
          for (final d in days) ...[
            Padding(
              padding: const EdgeInsets.only(top: 14, bottom: 2),
              child: Text(
                '${dayName(d)} $d${d == todayKey ? ' (النهارده)' : ''}  ·  ${by[d]!.where((t) => t.done).length}/${by[d]!.length}',
                style: TextStyle(
                  fontSize: 19,
                  color: brown,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ...by[d]!.map(row),
          ],
        ],
      ),
    );
  }

  Widget subjectsTab() => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Text(
        'المواد',
        style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: bg),
      ),
      if (subjects.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(
            'ضيف موادك من تبويب «إعداد».',
            style: TextStyle(color: sage, fontSize: 18),
          ),
        ),
      for (final s in subjects) ...[
        const SizedBox(height: 16),
        Text(
          '${s.name}  ·  ${doneOf(s)} / ${s.total}',
          style: TextStyle(fontSize: 22, color: sage),
        ),
        const SizedBox(height: 6),
        paper(
          tasks.where((t) => t.subject == s.name).isEmpty
              ? [
                  Text(
                    'مفيش مهام متبقية',
                    style: TextStyle(color: brown, fontSize: 18),
                  ),
                ]
              : tasks.where((t) => t.subject == s.name).map(row).toList(),
        ),
      ],
    ],
  );

  Future<void> editSubject([Subject? old]) async {
    final nameC = TextEditingController(text: old?.name ?? '');
    var total = old?.total ?? 10;
    var done = old == null ? 0 : doneOf(old);
    var exam = old?.exam ?? DateTime.now().add(const Duration(days: 14));
    var label = old?.label ?? 'شابتر';
    String? err;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          backgroundColor: cream,
          title: Text(
            old == null ? 'مادة جديدة' : 'تعديل المادة',
            style: TextStyle(color: bg),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameC,
                  style: TextStyle(color: bg, fontSize: 18),
                  decoration: InputDecoration(
                    hintText: 'اسم المادة',
                    errorText: err,
                    hintStyle: TextStyle(color: brown),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final l in ['شابتر', 'محاضرة', 'درس', 'جزء'])
                      ChoiceChip(
                        label: Text(
                          l,
                          style: TextStyle(color: label == l ? onAccent : bg),
                        ),
                        selected: label == l,
                        selectedColor: leafGreen,
                        backgroundColor: isDark
                            ? const Color(0xFF2C3930)
                            : const Color(0xFFEAEDE7),
                        showCheckmark: false,
                        onSelected: (_) => set(() => label = l),
                      ),
                  ],
                ),
                stepper('الإجمالي ($label)', total, (v) {
                  set(() {
                    total = v;
                    if (done > total) done = total;
                  });
                }, min: 1),
                stepper(
                  'خلّصت كام',
                  done,
                  (v) => set(() => done = v),
                  max: total,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('تاريخ الامتحان', style: TextStyle(color: bg)),
                  subtitle: Text(ymd(exam), style: TextStyle(color: brown)),
                  trailing: Icon(Icons.edit_calendar, color: brown),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: exam,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (d != null) set(() => exam = d);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: leafGreen,
                foregroundColor: onAccent,
              ),
              onPressed: () {
                final nm = nameC.text.trim();
                if (nm.isEmpty) {
                  set(() => err = 'اكتب اسم المادة');
                  return;
                }
                if (nm == extraName ||
                    subjects.any((s) => s.name == nm && s.id != old?.id)) {
                  set(() => err = 'الاسم ده مستخدم قبل كده');
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    final nm = nameC.text.trim();
    if (ok != true) return;
    setState(() {
      if (old == null) {
        subjects.add(
          Subject(
            's${DateTime.now().microsecondsSinceEpoch}',
            nm,
            total,
            done,
            exam,
            label,
          ),
        );
      } else {
        final doneTasks = tasks
            .where((t) => t.subject == old.name && t.done)
            .length;
        for (final t in tasks) {
          if (t.subject == old.name) t.subject = nm;
        }
        old
          ..name = nm
          ..total = total
          ..done = (done - doneTasks).clamp(0, total).toInt()
          ..exam = exam
          ..label = label;
      }
    });
    save();
  }

  void removeSubject(Subject s) {
    setState(() {
      tasks.removeWhere((t) => t.subject == s.name);
      subjects.remove(s);
    });
    save();
  }

  Future<void> confirmRemoveSubject(Subject s) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cream,
        title: Text('حذف ${s.name}؟', style: TextStyle(color: bg)),
        content: Text(
          'سيتم حذف المادة وكل المهام المرتبطة بها. لا يمكن التراجع عن هذا الإجراء.',
          style: TextStyle(color: brown),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB3472F),
              foregroundColor: onAccent,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed == true) removeSubject(s);
  }

  void gen() {
    if (subjects.isEmpty) {
      snack('ضيف مادة واحدة على الأقل');
      return;
    }
    for (final s in subjects) {
      s.done = doneOf(s);
    }
    final extras = tasks.where((t) => t.subject == extraName).toList();
    final r = generate(subjects, hours, minsPer);
    setState(() {
      tasks = [...r.tasks, ...extras];
      overflow = r.overflow;
      tab = 0;
    });
    save();
  }

  Widget setup() => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Text(
        'إعداد',
        style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: bg),
      ),
      const SizedBox(height: 4),
      Text(
        'ضيف موادك ووصلت لحد فين، والتطبيق يوزّع المذاكرة لحد الامتحان.',
        style: TextStyle(color: sage, fontSize: 18),
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: Text(
              'موادك',
              style: TextStyle(
                color: bg,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: leafGreen,
              foregroundColor: onAccent,
            ),
            onPressed: () => editSubject(),
            icon: const Icon(Icons.add),
            label: const Text('مادة'),
          ),
        ],
      ),
      const SizedBox(height: 8),
      if (subjects.isEmpty)
        paper([
          Text(
            'لسه مفيش مواد. دوس «مادة» وابدأ.',
            style: TextStyle(color: brown, fontSize: 18),
          ),
        ]),
      for (final s in subjects)
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
          decoration: BoxDecoration(
            color: cream,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.name,
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                        color: bg,
                      ),
                    ),
                    Text(
                      '${s.total} ${s.label} · خلّصت ${doneOf(s)} · امتحان ${ymd(s.exam)}',
                      style: TextStyle(color: brown, fontSize: 15),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => editSubject(s),
                icon: Icon(Icons.edit, color: leafGreen),
              ),
              IconButton(
                onPressed: () => confirmRemoveSubject(s),
                icon: Icon(Icons.delete_outline, color: brown),
              ),
            ],
          ),
        ),
      const SizedBox(height: 14),
      Text(
        'ساعات المذاكرة في اليوم: ${hours.toStringAsFixed(1)}',
        style: TextStyle(color: bg, fontSize: 18),
      ),
      Slider(
        value: hours,
        min: 1,
        max: 10,
        divisions: 18,
        activeColor: sage,
        onChanged: (v) => setState(() => hours = v),
        onChangeEnd: (_) => save(),
      ),
      Text(
        'مدة المهمة الواحدة (دقيقة)',
        style: TextStyle(color: bg, fontSize: 18),
      ),
      const SizedBox(height: 6),
      Wrap(
        spacing: 8,
        children: [
          for (final m in [30, 45, 60, 90, 120])
            ChoiceChip(
              label: Text('$m', style: TextStyle(color: onAccent)),
              selected: minsPer == m,
              selectedColor: leafGreen,
              backgroundColor: deep,
              showCheckmark: false,
              onSelected: (_) {
                setState(() => minsPer = m);
                save();
              },
            ),
        ],
      ),
      const SizedBox(height: 20),
      FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: cream,
          foregroundColor: bg,
          padding: const EdgeInsets.all(14),
        ),
        onPressed: gen,
        child: const Text('ولّد الخطة', style: TextStyle(fontSize: 20)),
      ),
      const SizedBox(height: 8),
      Text(
        'اللي خلّصته من المهام بيتحسب تلقائي لما تولّد الخطة تاني.',
        style: TextStyle(color: sage, fontSize: 15),
      ),
    ],
  );

  Future<void> quickAdd() async {
    final c = TextEditingController();
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cream,
        title: Text('مهمة سريعة لليوم', style: TextStyle(color: bg)),
        content: TextField(
          controller: c,
          autofocus: true,
          style: TextStyle(color: bg),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => Navigator.pop(ctx, c.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, c.text),
            child: const Text('أضف'),
          ),
        ],
      ),
    );
    if (v != null && v.trim().isNotEmpty) {
      setState(
        () => tasks.add(
          Task(
            'q${DateTime.now().millisecondsSinceEpoch}',
            ymd(DateTime.now()),
            extraName,
            v.trim(),
            30,
          ),
        ),
      );
      save();
    }
  }

  Widget navBar() {
    Widget item(int i, IconData ic, String l) => Expanded(
      child: InkWell(
        onTap: () => setState(() => tab = i),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(ic, color: tab == i ? navForeground : sage.withOpacity(0.7)),
            Text(
              l,
              style: TextStyle(
                fontSize: 13,
                color: tab == i ? navForeground : sage.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
    return Container(
      height: 76,
      decoration: BoxDecoration(
        color: deep,
        border: Border(top: BorderSide(color: sage.withOpacity(0.25))),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Row(
            children: [
              item(0, Icons.home_outlined, 'الرئيسية'),
              item(1, Icons.auto_stories_outlined, 'الخطة'),
              const SizedBox(width: 72),
              item(2, Icons.eco_outlined, 'المواد'),
              item(3, Icons.tune, 'إعداد'),
            ],
          ),
          Positioned(
            top: -24,
            child: Breathe(
              child: GestureDetector(
                onTap: quickAdd,
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: brown,
                    border: Border.all(color: canvasColorFor(isDark), width: 4),
                  ),
                  child: Icon(Icons.eco, color: onAccent),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: [home(), plan(), subjectsTab(), setup()][tab]),
    bottomNavigationBar: SafeArea(top: false, child: navBar()),
  );
}
