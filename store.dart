// حالة التطبيق + التخزين المحلي + التايمر.
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'logic.dart';

final ValueNotifier<ThemeMode> appThemeMode = ValueNotifier(ThemeMode.light);

enum Phase { focus, rest }

class AppStore extends ChangeNotifier {
  // ── البيانات ──
  List<Subject> subjects = [];
  List<Task> tasks = [];
  List<Session> sessions = [];
  Map<String, Map<int, ChapterInfo>> chapters = {};

  // ── الإعدادات ──
  double hours = 4;
  int minsPer = 60;
  int startMin = 16 * 60;
  int focusMin = 25;
  int breakMin = 5;
  int goalDay = 120;
  int goalWeek = 600;
  bool showAch = true;
  int overflow = 0;
  bool dark = false;

  bool loaded = false;
  String? error;

  // ── التايمر ──
  Phase phase = Phase.focus;
  bool timerRunning = false;
  int remaining = 25 * 60;
  String? timerSubjectId;
  String? timerTaskId;
  Session? lastSession;
  Timer? _ticker;
  DateTime? _endAt;
  DateTime? _phaseStart;
  DateTime? _recordedStart;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  // ───────────── تحميل وحفظ ─────────────

  List<T> _readList<T>(
    SharedPreferences p,
    String key,
    T Function(Map<String, dynamic>) f,
  ) {
    final raw = p.getString(key);
    if (raw == null) return <T>[];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => f(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      // نحتفظ بنسخة من النص التالف بدل ما نكتب فوقه.
      p.setString('${key}_corrupt', raw);
      error = 'بعض البيانات المحفوظة كانت تالفة وتم حفظ نسخة منها';
      return <T>[];
    }
  }

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      dark = p.getBool('darkMode') == true;
      appThemeMode.value = dark ? ThemeMode.dark : ThemeMode.light;
      hours = p.getDouble('hours') ?? 4;
      minsPer = p.getInt('minsPer') ?? 60;
      overflow = p.getInt('overflow') ?? 0;
      startMin = p.getInt('startMin') ?? 16 * 60;
      focusMin = p.getInt('focusMin') ?? 25;
      breakMin = p.getInt('breakMin') ?? 5;
      goalDay = p.getInt('goalDay') ?? 120;
      goalWeek = p.getInt('goalWeek') ?? 600;
      showAch = p.getBool('ach') ?? true;
      subjects = _readList<Subject>(p, 'subjects', Subject.fromJson);
      tasks = _readList<Task>(p, 'tasks', Task.fromJson);
      sessions = _readList<Session>(p, 'sessions', Session.fromJson);
      final ch = p.getString('chapters');
      if (ch != null) {
        try {
          chapters = chaptersFromJson(jsonDecode(ch));
        } catch (_) {
          p.setString('chapters_corrupt', ch);
          chapters = {};
        }
      }
    } catch (_) {
      error = 'تعذّر تحميل البيانات المحفوظة';
    }
    _migrate();
    tasks.sort(cmpTask);
    remaining = phaseSeconds;
    loaded = true;
    notifyListeners();
    save();
  }

  /// يحوّل مهام النسخ القديمة (بدون رقم شابتر) للصيغة الجديدة بدون فقد أي تقدّم.
  void _migrate() {
    final re = RegExp(r'(\d+)\s*$');
    for (final t in tasks) {
      if (t.unit != null || t.subject == extraName) continue;
      final s = subjectByName(t.subject);
      final m = re.firstMatch(t.title);
      if (s == null || m == null) continue;
      final k = int.parse(m.group(1)!);
      if (k < 1 || k > s.total) continue;
      t.unit = k;
      if (t.done && chapters[s.id]?[k]?.status == null) {
        infoFor(s.id, k).status = 2;
      }
    }
  }

  Future<bool> save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(
        'tasks',
        jsonEncode(tasks.map((t) => t.toJson()).toList()),
      );
      await p.setString(
        'subjects',
        jsonEncode(subjects.map((s) => s.toJson()).toList()),
      );
      await p.setString(
        'sessions',
        jsonEncode(sessions.map((s) => s.toJson()).toList()),
      );
      await p.setString('chapters', jsonEncode(chaptersToJson(chapters)));
      await p.setDouble('hours', hours);
      await p.setInt('minsPer', minsPer);
      await p.setInt('overflow', overflow);
      await p.setInt('startMin', startMin);
      await p.setInt('focusMin', focusMin);
      await p.setInt('breakMin', breakMin);
      await p.setInt('goalDay', goalDay);
      await p.setInt('goalWeek', goalWeek);
      await p.setBool('ach', showAch);
      return true;
    } catch (_) {
      error = 'تعذّر حفظ البيانات على الجهاز';
      notifyListeners();
      return false;
    }
  }

  /// بعد أي تعديل: حدّث الشاشات واحفظ.
  void touch() {
    notifyListeners();
    save();
  }

  Future<void> toggleTheme() async {
    dark = !dark;
    appThemeMode.value = dark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool('darkMode', dark);
    } catch (_) {
      error = 'تعذّر حفظ إعداد المظهر';
      notifyListeners();
    }
  }

  // ───────────── بحث ─────────────

  Subject? subjectByName(String n) {
    for (final s in subjects) {
      if (s.name == n) return s;
    }
    return null;
  }

  Subject? subjectById(String? id) {
    if (id == null) return null;
    for (final s in subjects) {
      if (s.id == id) return s;
    }
    return null;
  }

  Task? taskById(String? id) {
    if (id == null) return null;
    for (final t in tasks) {
      if (t.id == id) return t;
    }
    return null;
  }

  // ───────────── الشابترات والمراجعة ─────────────

  ChapterInfo infoFor(String sid, int n) => chapters
      .putIfAbsent(sid, () => <int, ChapterInfo>{})
      .putIfAbsent(n, () => ChapterInfo());

  /// 0 لم يبدأ، 1 جاري، 2 مكتمل.
  int chapterState(Subject s, int i) {
    final st = chapters[s.id]?[i]?.status;
    if (st != null) return st;
    return i <= s.done ? 2 : 0;
  }

  String chapterNote(Subject s, int i) => chapters[s.id]?[i]?.note ?? '';

  int doneOf(Subject s) {
    var c = 0;
    for (var i = 1; i <= s.total; i++) {
      if (chapterState(s, i) == 2) c++;
    }
    return c;
  }

  List<int> pendingChapters(Subject s) => [
    for (var i = 1; i <= s.total; i++)
      if (chapterState(s, i) != 2) i,
  ];

  void setChapterState(Subject s, int i, int state) {
    infoFor(s.id, i).status = state;
    if (state == 2) {
      final today = ymd(DateTime.now());
      for (final t in tasks) {
        if (t.subject == s.name && t.unit == i && !t.done) {
          t.done = true;
          t.doneDate = today;
        }
      }
    }
    touch();
  }

  void setChapterNote(Subject s, int i, String note) {
    infoFor(s.id, i).note = note.trim();
    touch();
  }

  // ───────────── المواد ─────────────

  void addSubject(
    String name,
    int total,
    int done,
    DateTime exam,
    String label,
  ) {
    subjects.add(
      Subject(
        's${DateTime.now().microsecondsSinceEpoch}',
        name,
        total,
        done.clamp(0, total).toInt(),
        exam,
        label,
      ),
    );
    touch();
  }

  void updateSubject(
    Subject old, {
    required String name,
    required int total,
    required int done,
    required DateTime exam,
    required String label,
  }) {
    final prev = doneOf(old);
    if (name != old.name) {
      for (final t in tasks) {
        if (t.subject == old.name) t.subject = name;
      }
      for (final s in sessions) {
        if (s.subject == old.name) s.subject = name;
      }
    }
    old
      ..name = name
      ..total = total
      ..exam = exam
      ..label = label;
    final wanted = done.clamp(0, total).toInt();
    if (wanted != prev) {
      old.done = wanted;
      chapters[old.id]?.forEach((k, v) => v.status = null);
    }
    touch();
  }

  void removeSubject(Subject s) {
    tasks.removeWhere((t) => t.subject == s.name);
    chapters.remove(s.id);
    subjects.remove(s);
    if (timerSubjectId == s.id) timerSubjectId = null;
    touch();
  }

  // ───────────── المهام ─────────────

  void toggleTask(Task t) {
    t.done = !t.done;
    t.doneDate = t.done ? ymd(DateTime.now()) : null;
    final s = subjectByName(t.subject);
    final u = t.unit;
    if (s != null && u != null && u >= 1 && u <= s.total) {
      if (t.done) {
        infoFor(s.id, u).status = 2;
      } else if (chapterState(s, u) == 2) {
        final otherDone = tasks.any(
          (x) => x != t && x.subject == t.subject && x.unit == u && x.done,
        );
        if (!otherDone) infoFor(s.id, u).status = null;
      }
    }
    touch();
  }

  int removeTask(Task t) {
    final i = tasks.indexOf(t);
    if (i >= 0) tasks.removeAt(i);
    if (timerTaskId == t.id) timerTaskId = null;
    touch();
    return i;
  }

  void restoreTask(int i, Task t) {
    tasks.insert(i.clamp(0, tasks.length).toInt(), t);
    tasks.sort(cmpTask);
    touch();
  }

  void addQuick(String title) {
    final now = DateTime.now();
    tasks.add(
      Task('q${now.millisecondsSinceEpoch}', ymd(now), extraName, title, 30),
    );
    tasks.sort(cmpTask);
    touch();
  }

  Task? conflictWith(String excludeId, String date, int? start, int mins) {
    if (start == null) return null;
    for (final o in tasks) {
      final os = o.start;
      if (o.id == excludeId || o.date != date || os == null) continue;
      if (start < os + o.mins && start + mins > os) return o;
    }
    return null;
  }

  void updateTask(
    Task t, {
    required String title,
    required String date,
    required int mins,
    required int? start,
  }) {
    t
      ..title = title
      ..date = date
      ..mins = mins
      ..start = start;
    tasks.sort(cmpTask);
    touch();
  }

  int get undoneGenerated =>
      tasks.where((t) => !t.done && t.unit != null).length;

  int get missedCount {
    final today = ymd(DateTime.now());
    return tasks
        .where((t) => !t.done && t.unit != null && t.date.compareTo(today) < 0)
        .length;
  }

  List<Task> get overdueTasks {
    final today = ymd(DateTime.now());
    return tasks
        .where((t) => !t.done && t.date.compareTo(today) < 0)
        .toList();
  }

  List<Task> tasksOn(String key) => tasks.where((t) => t.date == key).toList();

  Task? get nextTask {
    final today = ymd(DateTime.now());
    final open = tasks
        .where((t) => !t.done && t.date.compareTo(today) >= 0)
        .toList();
    if (open.isEmpty) return null;
    open.sort(cmpTask);
    return open.first;
  }

  /// يعيد توزيع الشابترات غير المكتملة. المهام المخلّصة والإضافية لا تُمس.
  void regenerate() {
    final kept = tasks.where((t) => t.done || t.unit == null).toList();
    final pending = <String, List<int>>{
      for (final s in subjects) s.id: pendingChapters(s),
    };
    final r = generatePlan(
      now: DateTime.now(),
      subjects: subjects,
      pending: pending,
      kept: kept,
      hours: hours,
      minsPer: minsPer,
      startMin: startMin,
    );
    tasks = [...kept, ...r.tasks]..sort(cmpTask);
    overflow = r.overflow;
    touch();
  }

  void setHours(double v) {
    hours = v;
    notifyListeners();
  }

  void setMinsPer(int v) {
    minsPer = v;
    touch();
  }

  void setStartMin(int v) {
    startMin = v;
    touch();
  }

  void setGoalDay(int v) {
    goalDay = v.clamp(15, 720).toInt();
    touch();
  }

  void setGoalWeek(int v) {
    goalWeek = v.clamp(60, 5000).toInt();
    touch();
  }

  void setShowAch(bool v) {
    showAch = v;
    touch();
  }

  // ───────────── الإحصائيات (من البيانات المسجّلة فقط) ─────────────

  int minutesOn(String key) {
    var m = 0;
    for (final s in sessions) {
      if (s.date == key) m += s.mins;
    }
    return m;
  }

  int get totalMinutes => sessions.fold<int>(0, (a, s) => a + s.mins);

  /// دقائق آخر [n] يوم (يشمل النهارده) بعد إزاحة [offset] يوم للخلف.
  int minutesInRange(int n, {int offset = 0}) {
    final today = dayOnly(DateTime.now());
    var m = 0;
    for (var i = 0; i < n; i++) {
      final d = DateTime(today.year, today.month, today.day - offset - i);
      m += minutesOn(ymd(d));
    }
    return m;
  }

  Set<String> get activityDays {
    final out = <String>{};
    for (final s in sessions) {
      out.add(s.date);
    }
    for (final t in tasks) {
      if (t.done && t.doneDate != null) out.add(t.doneDate!);
    }
    return out;
  }

  int get streak => computeStreak(activityDays, DateTime.now());
  int get longestStreak => bestStreak(activityDays);
  int get doneTasksCount => tasks.where((t) => t.done).length;

  List<AchGroup> get achievements => [
    AchGroup('جلسات التركيز', 'جلسة', sessions.length, [1, 10, 25, 50, 100]),
    AchGroup('أطول سلسلة أيام', 'يوم', longestStreak, [3, 7, 14, 30, 60]),
    AchGroup('ساعات المذاكرة المسجّلة', 'ساعة', totalMinutes ~/ 60, [
      1,
      5,
      10,
      25,
      50,
      100,
    ]),
    AchGroup('مهام مكتملة', 'مهمة', doneTasksCount, [5, 25, 50, 100, 250]),
  ];

  // ───────────── التايمر ─────────────

  int get phaseSeconds => (phase == Phase.focus ? focusMin : breakMin) * 60;
  bool get timerStarted => timerRunning || remaining < phaseSeconds;

  void setFocusMin(int v) {
    focusMin = v.clamp(1, 180).toInt();
    if (!timerStarted && phase == Phase.focus) remaining = phaseSeconds;
    touch();
  }

  void setBreakMin(int v) {
    breakMin = v.clamp(1, 60).toInt();
    if (!timerStarted && phase == Phase.rest) remaining = phaseSeconds;
    touch();
  }

  void selectSubject(String? id) {
    timerSubjectId = id;
    final t = taskById(timerTaskId);
    if (t != null && subjectByName(t.subject)?.id != id) timerTaskId = null;
    notifyListeners();
  }

  void selectTask(Task? t) {
    timerTaskId = t?.id;
    if (t != null) timerSubjectId = subjectByName(t.subject)?.id;
    notifyListeners();
  }

  void startTimer() {
    if (timerRunning) return;
    if (remaining <= 0) remaining = phaseSeconds;
    _phaseStart ??= DateTime.now();
    _endAt = DateTime.now().add(Duration(seconds: remaining));
    timerRunning = true;
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    notifyListeners();
  }

  void pauseTimer() {
    if (!timerRunning) return;
    _tick();
    if (!timerRunning) return;
    _ticker?.cancel();
    timerRunning = false;
    _endAt = null;
    notifyListeners();
  }

  void _tick() {
    final end = _endAt;
    if (end == null) return;
    final ms = end.difference(DateTime.now()).inMilliseconds;
    if (ms <= 0) {
      _finishPhase();
    } else {
      remaining = (ms + 999) ~/ 1000;
      notifyListeners();
    }
  }

  void _finishPhase() {
    _ticker?.cancel();
    timerRunning = false;
    _endAt = null;
    if (phase == Phase.focus) {
      _recordSession(focusMin);
      phase = Phase.rest;
    } else {
      phase = Phase.focus;
    }
    _phaseStart = null;
    remaining = phaseSeconds;
    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.alert);
    notifyListeners();
  }

  /// تسجّل الجلسة مرة واحدة فقط لكل فترة تركيز.
  void _recordSession(int mins) {
    final start = _phaseStart;
    if (start == null || _recordedStart == start || mins < 1) return;
    _recordedStart = start;
    final now = DateTime.now();
    final task = taskById(timerTaskId);
    final name = subjectById(timerSubjectId)?.name ?? task?.subject ?? generalName;
    final s = Session(
      'ss${now.microsecondsSinceEpoch}',
      ymd(now),
      name,
      timerTaskId,
      mins,
      now.millisecondsSinceEpoch,
    );
    sessions.add(s);
    lastSession = s;
    save();
  }

  /// إنهاء جلسة التركيز قبل وقتها وتسجيل الوقت المنقضي (لو دقيقة أو أكتر).
  void finishEarly() {
    if (!timerStarted || phase != Phase.focus) return;
    if (timerRunning) _tick();
    final elapsed = (phaseSeconds - remaining) ~/ 60;
    _ticker?.cancel();
    timerRunning = false;
    _endAt = null;
    if (elapsed >= 1) _recordSession(elapsed);
    _phaseStart = null;
    remaining = phaseSeconds;
    notifyListeners();
  }

  void resetTimer() {
    _ticker?.cancel();
    timerRunning = false;
    _endAt = null;
    _phaseStart = null;
    remaining = phaseSeconds;
    notifyListeners();
  }

  void skipBreak() {
    if (phase != Phase.rest) return;
    resetTimer();
    phase = Phase.focus;
    remaining = phaseSeconds;
    notifyListeners();
  }

  void startSessionFor(Task t) {
    if (timerStarted) return;
    if (phase != Phase.focus) {
      phase = Phase.focus;
      remaining = phaseSeconds;
    }
    selectTask(t);
    startTimer();
  }

  void dismissLastSession() {
    lastSession = null;
    notifyListeners();
  }

  // ───────────── النسخ الاحتياطي ─────────────

  BackupData snapshot() => BackupData(
    subjects: subjects,
    tasks: tasks,
    sessions: sessions,
    chapters: chapters,
    hours: hours,
    minsPer: minsPer,
    startMin: startMin,
    focusMin: focusMin,
    breakMin: breakMin,
    goalDay: goalDay,
    goalWeek: goalWeek,
    showAch: showAch,
    dark: dark,
  );

  String exportBackup() => encodeBackup(snapshot());

  /// يستبدل البيانات بعد حفظ نسخة أمان من الحالية.
  Future<bool> applyBackup(BackupData d) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString('pre_import_backup', exportBackup());
    } catch (_) {
      error = 'تعذّر حفظ نسخة الأمان، تم إلغاء الاستعادة';
      notifyListeners();
      return false;
    }
    resetTimer();
    lastSession = null;
    timerTaskId = null;
    timerSubjectId = null;
    subjects = d.subjects;
    tasks = d.tasks..sort(cmpTask);
    sessions = d.sessions;
    chapters = d.chapters;
    hours = d.hours;
    minsPer = d.minsPer;
    startMin = d.startMin;
    focusMin = d.focusMin;
    breakMin = d.breakMin;
    goalDay = d.goalDay;
    goalWeek = d.goalWeek;
    showAch = d.showAch;
    dark = d.dark;
    appThemeMode.value = dark ? ThemeMode.dark : ThemeMode.light;
    remaining = phaseSeconds;
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool('darkMode', dark);
    } catch (_) {}
    return save();
  }
}
