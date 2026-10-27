// منطق التطبيق الصافي (بدون Flutter) - قابل للاختبار.
import 'dart:convert';

const extraName = 'إضافي';
const generalName = 'عام';
const backupVersion = 1;

String ymd(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// عدد الأيام بين تاريخين (آمن مع تغيير التوقيت الصيفي).
int daysBetween(DateTime from, DateTime to) =>
    DateTime.utc(to.year, to.month, to.day)
        .difference(DateTime.utc(from.year, from.month, from.day))
        .inDays;

const weekdaysAr = [
  'الإثنين',
  'الثلاثاء',
  'الأربعاء',
  'الخميس',
  'الجمعة',
  'السبت',
  'الأحد',
];

const weekdaysShort = [
  'إثنين',
  'ثلاثاء',
  'أربعاء',
  'خميس',
  'جمعة',
  'سبت',
  'أحد',
];

String dayName(String ymdStr) {
  final d = DateTime.tryParse(ymdStr);
  return d == null ? '' : weekdaysAr[d.weekday - 1];
}

String examLabel(DateTime e) {
  final d = daysBetween(DateTime.now(), e);
  if (d < 0) return 'الامتحان عدّى';
  if (d == 0) return 'الامتحان النهارده';
  if (d == 1) return 'الامتحان بكرة';
  return 'الامتحان بعد $d يوم';
}

String fmtTime(int m) {
  final h24 = (m ~/ 60) % 24;
  final mm = m % 60;
  final h = h24 % 12 == 0 ? 12 : h24 % 12;
  return '$h:${mm.toString().padLeft(2, '0')} ${h24 < 12 ? 'ص' : 'م'}';
}

String fmtMins(int m) {
  if (m < 60) return '$m د';
  final h = m ~/ 60;
  final r = m % 60;
  return r == 0 ? '$h س' : '$h س $r د';
}

// ───────────────────────── النماذج ─────────────────────────

class Subject {
  String id, name, label;
  int total, done; // done = عدد الشابترات المكتملة "الأساسية" قبل التتبع
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
    j['i'] as String,
    j['n'] as String,
    (j['t'] as num).toInt(),
    (j['d'] as num).toInt(),
    DateTime.fromMillisecondsSinceEpoch((j['e'] as num).toInt()),
    (j['l'] as String?) ?? 'شابتر',
  );
}

class Task {
  String id, date, subject, title;
  int mins;
  bool done;
  int? unit; // رقم الشابتر (للمهام المولّدة)
  int? start; // وقت البداية بالدقائق من منتصف الليل
  String? doneDate; // تاريخ الإنجاز
  Task(
    this.id,
    this.date,
    this.subject,
    this.title,
    this.mins, {
    this.done = false,
    this.unit,
    this.start,
    this.doneDate,
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date,
    's': subject,
    't': title,
    'm': mins,
    'd': done,
    if (unit != null) 'u': unit,
    if (start != null) 'st': start,
    if (doneDate != null) 'dd': doneDate,
  };
  factory Task.fromJson(Map<String, dynamic> j) => Task(
    j['id'] as String,
    j['date'] as String,
    j['s'] as String,
    j['t'] as String,
    (j['m'] as num).toInt(),
    done: (j['d'] as bool?) ?? false,
    unit: (j['u'] as num?)?.toInt(),
    start: (j['st'] as num?)?.toInt(),
    doneDate: j['dd'] as String?,
  );
}

int cmpTask(Task a, Task b) {
  final c = a.date.compareTo(b.date);
  if (c != 0) return c;
  return (a.start ?? 99999).compareTo(b.start ?? 99999);
}

/// جلسة تركيز مسجّلة من التايمر.
class Session {
  String id, date, subject;
  String? taskId;
  int mins, at;
  Session(this.id, this.date, this.subject, this.taskId, this.mins, this.at);
  Map<String, dynamic> toJson() => {
    'id': id,
    'd': date,
    's': subject,
    if (taskId != null) 'k': taskId,
    'm': mins,
    'at': at,
  };
  factory Session.fromJson(Map<String, dynamic> j) => Session(
    j['id'] as String,
    j['d'] as String,
    j['s'] as String,
    j['k'] as String?,
    (j['m'] as num).toInt(),
    (j['at'] as num).toInt(),
  );
}

/// حالة شابتر: 0 لم يبدأ، 1 جاري، 2 مكتمل (+ ملاحظة شخصية).
class ChapterInfo {
  int? status;
  String note;
  ChapterInfo({this.status, this.note = ''});
  bool get isEmpty => status == null && note.isEmpty;
  Map<String, dynamic> toJson() => {
    if (status != null) 's': status,
    if (note.isNotEmpty) 'n': note,
  };
  factory ChapterInfo.fromJson(Map<String, dynamic> j) {
    final s = (j['s'] as num?)?.toInt();
    if (s != null && (s < 0 || s > 2)) {
      throw const FormatException('حالة شابتر غير صالحة');
    }
    return ChapterInfo(status: s, note: (j['n'] as String?) ?? '');
  }
}

Map<String, dynamic> chaptersToJson(Map<String, Map<int, ChapterInfo>> m) {
  final out = <String, dynamic>{};
  m.forEach((sid, chs) {
    final inner = <String, dynamic>{};
    chs.forEach((k, v) {
      if (!v.isEmpty) inner['$k'] = v.toJson();
    });
    if (inner.isNotEmpty) out[sid] = inner;
  });
  return out;
}

Map<String, Map<int, ChapterInfo>> chaptersFromJson(Object? raw) {
  final out = <String, Map<int, ChapterInfo>>{};
  if (raw == null) return out;
  (raw as Map).forEach((sid, chs) {
    final inner = <int, ChapterInfo>{};
    (chs as Map).forEach((k, v) {
      inner[int.parse(k.toString())] = ChapterInfo.fromJson(
        Map<String, dynamic>.from(v as Map),
      );
    });
    out[sid.toString()] = inner;
  });
  return out;
}

// ───────────────────────── الجدولة ─────────────────────────

class PlanResult {
  final List<Task> tasks;
  final int overflow;
  PlanResult(this.tasks, this.overflow);
}

/// أول وقت بداية متاح من [from] بدون تداخل مع [occupied]، أو null لو مفيش مكان قبل نهاية اليوم.
int? findStart(List<List<int>> occupied, int from, int mins) {
  var c = from;
  var moved = true;
  while (moved) {
    moved = false;
    for (final o in occupied) {
      if (c < o[1] && c + mins > o[0]) {
        c = o[1];
        moved = true;
      }
    }
  }
  return c + mins <= 1440 ? c : null;
}

/// يوزّع الشابترات المتبقية ([pending]) على الأيام حتى الامتحانات.
/// [kept] مهام باقية (مخلّصة/إضافية) تُحسب في سعة اليوم ولا يحصل تداخل معها.
PlanResult generatePlan({
  required DateTime now,
  required List<Subject> subjects,
  required Map<String, List<int>> pending,
  required List<Task> kept,
  required double hours,
  required int minsPer,
  required int startMin,
}) {
  final start = dayOnly(now);
  final nowMin = now.hour * 60 + now.minute;
  final rem = <String, int>{};
  final idx = <String, int>{};
  final dl = <String, int>{};
  var horizon = 1;
  for (final s in subjects) {
    rem[s.id] = pending[s.id]?.length ?? 0;
    idx[s.id] = 0;
    var d = daysBetween(start, s.exam);
    if (d < 1) d = 1;
    if (d > 120) d = 120;
    dl[s.id] = d;
    if (rem[s.id]! > 0 && d > horizon) horizon = d;
  }

  final keptMins = <String, int>{};
  final occ = <String, List<List<int>>>{};
  for (final t in kept) {
    keptMins[t.date] = (keptMins[t.date] ?? 0) + t.mins;
    final st = t.start;
    if (st != null) {
      occ.putIfAbsent(t.date, () => <List<int>>[]).add([st, st + t.mins]);
    }
  }

  final out = <Task>[];
  var n = 0;
  var overflow = 0;
  final stamp = now.microsecondsSinceEpoch;

  Task mk(DateTime date, Subject s, int? st) {
    final k = pending[s.id]![idx[s.id]!];
    idx[s.id] = idx[s.id]! + 1;
    rem[s.id] = rem[s.id]! - 1;
    return Task(
      'g${stamp}_${n++}',
      ymd(date),
      s.name,
      '${s.label} $k',
      minsPer,
      unit: k,
      start: st,
    );
  }

  for (var day = 0; day < horizon; day++) {
    final date = DateTime(start.year, start.month, start.day + day);
    final key = ymd(date);
    final used = keptMins[key] ?? 0;
    var slots = ((hours * 60 - used) / minsPer).floor();
    if (slots < 1 && used == 0) slots = 1;
    if (slots > 50) slots = 50;
    if (slots < 0) slots = 0;
    final occupied = <List<int>>[...?occ[key]];
    var cursor = startMin;
    if (day == 0 && nowMin > cursor) cursor = ((nowMin + 14) ~/ 15) * 15;
    for (var slot = 0; slot < slots; slot++) {
      Subject? best;
      var bu = -1.0;
      for (final s in subjects) {
        if (rem[s.id]! <= 0 || day >= dl[s.id]!) continue;
        final u = rem[s.id]! / (dl[s.id]! - day);
        if (u > bu || (u == bu && best != null && s.exam.isBefore(best.exam))) {
          bu = u;
          best = s;
        }
      }
      if (best == null) break;
      final st = findStart(occupied, cursor, minsPer);
      if (st == null) break;
      occupied.add([st, st + minsPer]);
      cursor = st + minsPer;
      out.add(mk(date, best, st));
    }
  }

  // اللي ماتحطش قبل الامتحان: يتحط آخر يوم متاح بدون وقت محدد ونعدّه "زيادة".
  for (final s in subjects) {
    while (rem[s.id]! > 0) {
      final date = DateTime(start.year, start.month, start.day + dl[s.id]! - 1);
      out.add(mk(date, s, null));
      overflow++;
    }
  }
  out.sort(cmpTask);
  return PlanResult(out, overflow);
}

// ───────────────────────── الإحصائيات ─────────────────────────

int computeStreak(Set<String> days, DateTime today) {
  var d = dayOnly(today);
  if (!days.contains(ymd(d))) d = DateTime(d.year, d.month, d.day - 1);
  var n = 0;
  while (days.contains(ymd(d))) {
    n++;
    d = DateTime(d.year, d.month, d.day - 1);
  }
  return n;
}

int bestStreak(Set<String> days) {
  final list = days.map((s) => DateTime.tryParse(s)).whereType<DateTime>().toList()
    ..sort();
  var best = 0;
  var cur = 0;
  DateTime? prev;
  for (final d in list) {
    if (prev != null && daysBetween(prev, d) == 1) {
      cur++;
    } else {
      cur = 1;
    }
    if (cur > best) best = cur;
    prev = d;
  }
  return best;
}

class AchGroup {
  final String title, unit;
  final int value;
  final List<int> targets;
  AchGroup(this.title, this.unit, this.value, this.targets);
  int? get next {
    for (final t in targets) {
      if (t > value) return t;
    }
    return null;
  }

  int get unlocked => targets.where((t) => value >= t).length;
}

// ───────────────────────── النسخ الاحتياطي ─────────────────────────

class BackupData {
  final List<Subject> subjects;
  final List<Task> tasks;
  final List<Session> sessions;
  final Map<String, Map<int, ChapterInfo>> chapters;
  final double hours;
  final int minsPer, startMin, focusMin, breakMin, goalDay, goalWeek;
  final bool showAch, dark;
  BackupData({
    required this.subjects,
    required this.tasks,
    required this.sessions,
    required this.chapters,
    required this.hours,
    required this.minsPer,
    required this.startMin,
    required this.focusMin,
    required this.breakMin,
    required this.goalDay,
    required this.goalWeek,
    required this.showAch,
    required this.dark,
  });
}

String encodeBackup(BackupData d) => jsonEncode({
  'app': 'study_planner',
  'version': backupVersion,
  'exportedAt': DateTime.now().toIso8601String(),
  'subjects': d.subjects.map((e) => e.toJson()).toList(),
  'tasks': d.tasks.map((e) => e.toJson()).toList(),
  'sessions': d.sessions.map((e) => e.toJson()).toList(),
  'chapters': chaptersToJson(d.chapters),
  'settings': {
    'hours': d.hours,
    'minsPer': d.minsPer,
    'startMin': d.startMin,
    'focusMin': d.focusMin,
    'breakMin': d.breakMin,
    'goalDay': d.goalDay,
    'goalWeek': d.goalWeek,
    'ach': d.showAch,
    'dark': d.dark,
  },
});

/// يفحص النص ويرمي FormatException برسالة عربية لو فيه مشكلة. لا يغيّر أي بيانات.
BackupData decodeBackup(String text) {
  Object? raw;
  try {
    raw = jsonDecode(text.trim());
  } catch (_) {
    throw const FormatException('النص ده مش نسخة احتياطية صالحة');
  }
  if (raw is! Map || raw['app'] != 'study_planner') {
    throw const FormatException('الملف ده مش نسخة من مخطط الدراسة');
  }
  final map = Map<String, dynamic>.from(raw);
  final v = map['version'];
  if (v is! int || v < 1 || v > backupVersion) {
    throw const FormatException('إصدار النسخة غير مدعوم');
  }

  List<T> parseList<T>(String key, T Function(Map<String, dynamic>) f) {
    final l = map[key];
    if (l == null) return <T>[];
    if (l is! List) throw FormatException('قسم $key غير صالح');
    try {
      return l.map((e) => f(Map<String, dynamic>.from(e as Map))).toList();
    } catch (_) {
      throw FormatException('قسم $key فيه عنصر غير صالح');
    }
  }

  final subjects = parseList<Subject>('subjects', Subject.fromJson);
  final tasks = parseList<Task>('tasks', Task.fromJson);
  final sessions = parseList<Session>('sessions', Session.fromJson);
  if (subjects.map((s) => s.id).toSet().length != subjects.length) {
    throw const FormatException('فيه مواد مكرّرة في النسخة');
  }
  Map<String, Map<int, ChapterInfo>> chapters;
  try {
    chapters = chaptersFromJson(map['chapters']);
  } catch (_) {
    throw const FormatException('قسم الشابترات غير صالح');
  }

  final st = map['settings'] is Map
      ? Map<String, dynamic>.from(map['settings'] as Map)
      : <String, dynamic>{};
  int geti(String k, int def, int lo, int hi) {
    final x = st[k];
    if (x is num) return x.toInt().clamp(lo, hi).toInt();
    return def;
  }

  final h = st['hours'];
  return BackupData(
    subjects: subjects,
    tasks: tasks,
    sessions: sessions,
    chapters: chapters,
    hours: h is num ? h.toDouble().clamp(1.0, 10.0).toDouble() : 4.0,
    minsPer: geti('minsPer', 60, 15, 240),
    startMin: geti('startMin', 960, 0, 1380),
    focusMin: geti('focusMin', 25, 1, 180),
    breakMin: geti('breakMin', 5, 1, 60),
    goalDay: geti('goalDay', 120, 15, 720),
    goalWeek: geti('goalWeek', 600, 60, 5000),
    showAch: st['ach'] is bool ? st['ach'] as bool : true,
    dark: st['dark'] is bool ? st['dark'] as bool : false,
  );
}
