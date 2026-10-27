// شاشات "المزيد": المواد، الإعداد، التقدّم، المراجعة، الأهداف، النسخ الاحتياطي.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'logic.dart';
import 'screens_main.dart';
import 'store.dart';
import 'ui.dart';

// ───────────────────── قائمة المزيد ─────────────────────

class MoreMenu extends StatelessWidget {
  final GoFn go;
  const MoreMenu({super.key, required this.go});

  Widget _tile(IconData icon, String title, String sub, int page) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => go(3, page),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: leaf.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: sage),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: ink,
                    ),
                  ),
                  Text(sub, style: TextStyle(fontSize: 14, color: brown)),
                ],
              ),
            ),
            Icon(Icons.chevron_left, color: sage),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
    children: [
      pageTitle('المزيد'),
      const SizedBox(height: 14),
      _tile(Icons.menu_book_outlined, 'المواد', 'إضافة وتعديل المواد والامتحانات', 1),
      _tile(Icons.insights_outlined, 'التقدّم والإحصائيات', 'وقت المذاكرة والمنجز والاستعداد', 2),
      _tile(Icons.fact_check_outlined, 'المراجعة', 'حالة كل شابتر وملاحظاتك', 3),
      _tile(Icons.emoji_events_outlined, 'الأهداف والإنجازات', 'أهداف يومية وأسبوعية', 4),
      _tile(Icons.tune, 'إعدادات الجدولة', 'ساعات المذاكرة ووقت البداية', 5),
      _tile(Icons.backup_outlined, 'النسخ الاحتياطي', 'تصدير واستعادة بياناتك', 6),
    ],
  );
}

// ───────────────────── المواد ─────────────────────

Future<void> editSubjectFlow(
  BuildContext context,
  AppStore store, [
  Subject? old,
]) async {
  final nameC = TextEditingController(text: old?.name ?? '');
  var label = old?.label ?? 'شابتر';
  var total = old?.total ?? 10;
  var done = old == null ? 0 : store.doneOf(old);
  var exam = old?.exam ?? DateTime.now().add(const Duration(days: 30));
  String? err;
  final labels = <String>{'شابتر', 'وحدة', 'درس', 'باب', 'محاضرة', label};
  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        backgroundColor: card,
        title: Text(
          old == null ? 'مادة جديدة' : 'تعديل المادة',
          style: TextStyle(color: ink),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameC,
                style: TextStyle(color: ink),
                decoration: const InputDecoration(labelText: 'اسم المادة'),
              ),
              const SizedBox(height: 12),
              Text('نوع الوحدات', style: TextStyle(color: brown)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  for (final l in labels)
                    choice(l, l == label, () => set(() => label = l)),
                ],
              ),
              const SizedBox(height: 8),
              stepper(
                'العدد الكلي',
                total,
                (v) => set(() {
                  total = v;
                  if (done > total) done = total;
                }),
                min: 1,
                max: 300,
              ),
              stepper(
                'خلّصت كام',
                done,
                (v) => set(() => done = v),
                min: 0,
                max: total,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.event, color: leaf),
                title: Text('تاريخ الامتحان', style: TextStyle(color: ink)),
                subtitle: Text(
                  '${ymd(exam)} · ${examLabel(exam)}',
                  style: TextStyle(color: brown),
                ),
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
              if (err != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(err!, style: TextStyle(color: warn)),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: leaf,
              foregroundColor: onLeaf,
            ),
            onPressed: () {
              final nm = nameC.text.trim();
              if (nm.isEmpty) {
                set(() => err = 'اكتب اسم المادة');
                return;
              }
              final dup = store.subjects.any((s) => s != old && s.name == nm);
              if (dup || nm == extraName || nm == generalName) {
                set(() => err = 'الاسم ده مستخدم، اختار اسم تاني');
                return;
              }
              if (old == null) {
                store.addSubject(nm, total, done, exam, label);
              } else {
                store.updateSubject(
                  old,
                  name: nm,
                  total: total,
                  done: done,
                  exam: exam,
                  label: label,
                );
              }
              Navigator.pop(ctx);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    ),
  );
}

class SubjectsScreen extends StatelessWidget {
  final AppStore store;
  final GoFn go;
  const SubjectsScreen({super.key, required this.store, required this.go});

  @override
  Widget build(BuildContext context) {
    final subs = [...store.subjects]..sort((a, b) => a.exam.compareTo(b.exam));
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        pageTitle('المواد'),
        const SizedBox(height: 12),
        primaryButton(
          'أضف مادة',
          () => editSubjectFlow(context, store),
          icon: Icons.add,
        ),
        const SizedBox(height: 14),
        if (subs.isEmpty)
          paper([
            emptyState(
              icon: Icons.menu_book_outlined,
              text: 'لسه مفيش مواد. أضف مادتك الأولى مع تاريخ الامتحان.',
            ),
          ]),
        for (final s in subs) ...[
          paper([
            Row(
              children: [
                Expanded(child: heading(s.name, size: 20)),
                IconButton(
                  tooltip: 'تعديل',
                  icon: Icon(Icons.edit_outlined, color: sage),
                  onPressed: () => editSubjectFlow(context, store, s),
                ),
                IconButton(
                  tooltip: 'حذف',
                  icon: Icon(Icons.delete_outline, color: warn),
                  onPressed: () async {
                    final ok = await confirmDialog(
                      context,
                      'حذف «${s.name}»؟',
                      'هتتحذف المادة وكل مهامها المجدولة. جلسات التركيز المسجّلة هتفضل في السجل.',
                      yes: 'احذف',
                      danger: true,
                    );
                    if (ok) store.removeSubject(s);
                  },
                ),
              ],
            ),
            mutedText('${examLabel(s.exam)} · ${ymd(s.exam)}'),
            const SizedBox(height: 8),
            progressBar(s.total == 0 ? 0 : store.doneOf(s) / s.total),
            const SizedBox(height: 4),
            mutedText(
              'خلّصت ${store.doneOf(s)} من ${s.total} ${s.label}',
              size: 14,
            ),
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                iconColor: sage,
                collapsedIconColor: sage,
                textColor: ink,
                collapsedTextColor: ink,
                title: Text(
                  'المهام (${store.tasks.where((t) => t.subject == s.name).length})',
                  style: const TextStyle(fontSize: 16),
                ),
                children: [
                  ...store.tasks
                      .where((t) => t.subject == s.name)
                      .map((t) => taskRow(context, store, t)),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

// ───────────────────── إعدادات الجدولة ─────────────────────

class SetupScreen extends StatelessWidget {
  final AppStore store;
  final GoFn go;
  const SetupScreen({super.key, required this.store, required this.go});

  @override
  Widget build(BuildContext context) {
    final h = store.hours;
    final hLabel = h % 1 == 0 ? '${h.toInt()}' : h.toStringAsFixed(1);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        pageTitle('إعدادات الجدولة'),
        const SizedBox(height: 14),
        paper([
          heading('ساعات المذاكرة في اليوم', size: 18),
          Slider(
            min: 1,
            max: 10,
            divisions: 18,
            value: h.clamp(1.0, 10.0).toDouble(),
            label: hLabel,
            activeColor: leaf,
            onChanged: store.setHours,
            onChangeEnd: (_) => store.touch(),
          ),
          mutedText('$hLabel ساعة يومياً'),
          const SizedBox(height: 16),
          heading('مدة الجلسة الواحدة', size: 18),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final m in const [30, 45, 60, 90, 120])
                choice('$m د', store.minsPer == m, () => store.setMinsPer(m)),
            ],
          ),
          const SizedBox(height: 16),
          heading('وقت بداية المذاكرة', size: 18),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.schedule, color: leaf),
            title: Text(fmtTime(store.startMin), style: TextStyle(color: ink, fontSize: 18)),
            subtitle: Text(
              'الجلسات بتتحط ورا بعض من الوقت ده من غير تداخل',
              style: TextStyle(color: brown),
            ),
            onTap: () async {
              final r = await showTimePicker(
                context: context,
                initialTime: TimeOfDay(
                  hour: (store.startMin ~/ 60) % 24,
                  minute: store.startMin % 60,
                ),
              );
              if (r != null) store.setStartMin(r.hour * 60 + r.minute);
            },
          ),
        ]),
        const SizedBox(height: 14),
        primaryButton(
          'ولّد الخطة',
          () async {
            final ok = await generateFlow(context, store);
            if (ok) go(0);
          },
          icon: Icons.auto_awesome,
        ),
        const SizedBox(height: 8),
        mutedText(
          'بنوزّع الشابترات غير المكتملة على الأيام، وبنبدأ بالمواد اللي امتحانها أقرب. المهام المخلّصة مبتتمسحش.',
          size: 14,
        ),
      ],
    );
  }
}

// ───────────────────── التقدّم والإحصائيات ─────────────────────

class ProgressScreen extends StatelessWidget {
  final AppStore store;
  const ProgressScreen({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = dayOnly(now);
    final todayKey = ymd(today);
    final dayVals = <int>[];
    final dayLabels = <String>[];
    for (var i = 6; i >= 0; i--) {
      final d = DateTime(today.year, today.month, today.day - i);
      dayVals.add(store.minutesOn(ymd(d)));
      dayLabels.add(weekdaysShort[d.weekday - 1]);
    }
    final weekVals = [
      for (var k = 3; k >= 0; k--) store.minutesInRange(7, offset: 7 * k),
    ];
    final fromKey = ymd(DateTime(today.year, today.month, today.day - 6));
    final week = store.tasks
        .where((t) => t.date.compareTo(fromKey) >= 0 && t.date.compareTo(todayKey) <= 0)
        .toList();
    final weekDone = week.where((t) => t.done).length;
    final allTasks = store.tasks.length;
    final allDone = store.doneTasksCount;
    final subs = [...store.subjects]..sort((a, b) => a.exam.compareTo(b.exam));
    final upcoming = subs.where((s) => daysBetween(today, s.exam) >= 0).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        pageTitle('التقدّم'),
        const SizedBox(height: 14),
        Row(
          children: [
            statTile(Icons.hourglass_bottom, 'إجمالي الوقت', fmtMins(store.totalMinutes)),
            const SizedBox(width: 10),
            statTile(Icons.timer_outlined, 'جلسات التركيز', '${store.sessions.length}'),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            statTile(Icons.local_fire_department_outlined, 'السلسلة الحالية', '${store.streak} يوم'),
            const SizedBox(width: 10),
            statTile(Icons.military_tech_outlined, 'أطول سلسلة', '${store.longestStreak} يوم'),
          ],
        ),
        const SizedBox(height: 14),
        paper([
          heading('وقت المذاكرة آخر 7 أيام', size: 18),
          mutedText('الإجمالي: ${fmtMins(store.minutesInRange(7))} (بالدقايق)', size: 14),
          const SizedBox(height: 12),
          store.sessions.isEmpty
              ? mutedText('هيظهر الرسم لما تسجّل أول جلسة من التايمر.')
              : BarChart(values: dayVals, labels: dayLabels, highlight: 6),
        ]),
        const SizedBox(height: 14),
        paper([
          heading('وقت المذاكرة بالأسبوع', size: 18),
          const SizedBox(height: 12),
          store.sessions.isEmpty
              ? mutedText('لسه مفيش بيانات.')
              : BarChart(
                  values: weekVals,
                  labels: const ['من 3 أسابيع', 'من أسبوعين', 'الأسبوع اللي فات', 'الأسبوع ده'],
                  highlight: 3,
                ),
        ]),
        const SizedBox(height: 14),
        paper([
          heading('المخطط مقابل المنجز', size: 18),
          const SizedBox(height: 10),
          if (allTasks == 0)
            mutedText('مفيش مهام لسه.')
          else ...[
            mutedText('آخر 7 أيام: $weekDone من ${week.length} مهمة', size: 14),
            const SizedBox(height: 4),
            progressBar(week.isEmpty ? 0 : weekDone / week.length),
            const SizedBox(height: 12),
            mutedText('الإجمالي: $allDone من $allTasks مهمة', size: 14),
            const SizedBox(height: 4),
            progressBar(allDone / allTasks),
          ],
        ]),
        const SizedBox(height: 14),
        paper([
          heading('تقدّم المواد', size: 18),
          const SizedBox(height: 10),
          if (subs.isEmpty) mutedText('ضيف مواد عشان تظهر هنا.'),
          for (final s in subs)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          s.name,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ink),
                        ),
                      ),
                      Text(
                        '${store.doneOf(s)}/${s.total}',
                        style: TextStyle(color: brown),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  progressBar(s.total == 0 ? 0 : store.doneOf(s) / s.total),
                  const SizedBox(height: 2),
                  Text(
                    'مكتمل ${store.doneOf(s)} · متبقي ${s.total - store.doneOf(s)} ${s.label}',
                    style: TextStyle(fontSize: 13, color: brown),
                  ),
                ],
              ),
            ),
        ]),
        const SizedBox(height: 14),
        paper([
          heading('الاستعداد للامتحانات', size: 18),
          const SizedBox(height: 10),
          if (upcoming.isEmpty) mutedText('مفيش امتحانات قادمة.'),
          for (final s in upcoming)
            Builder(
              builder: (_) {
                final left = s.total - store.doneOf(s);
                final days = daysBetween(today, s.exam);
                final perDay = left == 0 ? 0 : (left / (days < 1 ? 1 : days)).ceil();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.name,
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ink),
                            ),
                            Text(
                              examLabel(s.exam),
                              style: TextStyle(fontSize: 13, color: brown),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        left == 0 ? 'جاهز ✓' : 'محتاج $perDay ${s.label}/يوم',
                        style: TextStyle(
                          color: left == 0 ? leaf : (perDay > 3 ? warn : brown),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ]),
      ],
    );
  }
}

// ───────────────────── المراجعة ─────────────────────

class RevisionScreen extends StatefulWidget {
  final AppStore store;
  const RevisionScreen({super.key, required this.store});
  @override
  State<RevisionScreen> createState() => _RevisionScreenState();
}

class _RevisionScreenState extends State<RevisionScreen> {
  String? selId;

  Future<void> _noteDialog(Subject s, int i) async {
    final store = widget.store;
    final c = TextEditingController(text: store.chapterNote(s, i));
    final r = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: card,
        title: Text('ملاحظات ${s.label} $i', style: TextStyle(color: ink)),
        content: TextField(
          controller: c,
          autofocus: true,
          maxLines: 5,
          style: TextStyle(color: ink),
          decoration: const InputDecoration(hintText: 'اكتب ملاحظاتك هنا'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: leaf,
              foregroundColor: onLeaf,
            ),
            onPressed: () => Navigator.pop(ctx, c.text),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (r != null) store.setChapterNote(s, i, r);
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final today = dayOnly(DateTime.now());
    final subs = [...store.subjects]..sort((a, b) => a.exam.compareTo(b.exam));
    if (subs.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          pageTitle('المراجعة'),
          const SizedBox(height: 14),
          paper([
            emptyState(
              icon: Icons.fact_check_outlined,
              text: 'ضيف مواد الأول عشان تتابع مراجعة كل شابتر.',
            ),
          ]),
        ],
      );
    }
    final sel = store.subjectById(selId) ?? subs.first;
    final daysLeft = daysBetween(today, sel.exam);
    final prio = <MapEntry<Subject, double>>[];
    for (final s in subs) {
      final rem = s.total - store.doneOf(s);
      final d = daysBetween(today, s.exam);
      if (rem > 0 && d >= 0) prio.add(MapEntry(s, rem / (d < 1 ? 1 : d)));
    }
    prio.sort((a, b) => b.value.compareTo(a.value));
    final doneSel = store.doneOf(sel);
    const names = ['لم يبدأ', 'جاري', 'مكتمل'];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        pageTitle('المراجعة'),
        const SizedBox(height: 14),
        if (prio.isNotEmpty) ...[
          paper([
            heading('أولويات المراجعة', size: 18),
            const SizedBox(height: 4),
            mutedText('مرتّبة حسب قرب الامتحان وحجم المتبقي', size: 14),
            const SizedBox(height: 8),
            for (var i = 0; i < prio.length && i < 5; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text(
                  '${i + 1}. ${prio[i].key.name} — متبقي ${prio[i].key.total - store.doneOf(prio[i].key)} · ${examLabel(prio[i].key.exam)}',
                  style: TextStyle(fontSize: 15, color: ink),
                ),
              ),
          ]),
          const SizedBox(height: 14),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final s in subs)
              choice(s.name, s.id == sel.id, () => setState(() => selId = s.id)),
          ],
        ),
        const SizedBox(height: 12),
        paper([
          heading(sel.name, size: 20),
          mutedText(
            '${examLabel(sel.exam)} · خلّصت $doneSel من ${sel.total} · متبقي ${sel.total - doneSel}',
            size: 14,
          ),
          const SizedBox(height: 8),
          progressBar(sel.total == 0 ? 0 : doneSel / sel.total),
          if (daysLeft >= 0 && daysLeft <= 14 && sel.total - doneSel > 0) ...[
            const SizedBox(height: 8),
            Text(
              'الامتحان قرّب وفاضل ${sel.total - doneSel} ${sel.label} ما اتخلّصوش',
              style: TextStyle(color: warn, fontSize: 14),
            ),
          ],
          const SizedBox(height: 6),
          mutedText('اضغط على أي ${sel.label} لتغيير حالته: لم يبدأ ← جاري ← مكتمل', size: 13),
        ]),
        const SizedBox(height: 12),
        for (var i = 1; i <= sel.total; i++)
          Builder(
            builder: (_) {
              final st = store.chapterState(sel, i);
              final note = store.chapterNote(sel, i);
              final urgent = daysLeft >= 0 && daysLeft <= 14 && st != 2;
              final color = st == 2 ? leaf : (st == 1 ? brown : sage);
              final ch = i;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: urgent ? warn.withOpacity(0.10) : leaf.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: urgent ? Border.all(color: warn.withOpacity(0.5)) : null,
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => store.setChapterState(sel, ch, (st + 1) % 3),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
                    child: Row(
                      children: [
                        Icon(
                          st == 2
                              ? Icons.check_circle
                              : (st == 1 ? Icons.timelapse : Icons.radio_button_unchecked),
                          color: color,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${sel.label} $ch',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ink),
                              ),
                              if (note.isNotEmpty)
                                Text(
                                  note,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 13, color: brown),
                                ),
                            ],
                          ),
                        ),
                        Text(names[st], style: TextStyle(color: color, fontSize: 14)),
                        IconButton(
                          tooltip: 'ملاحظات',
                          icon: Icon(
                            note.isEmpty ? Icons.note_add_outlined : Icons.sticky_note_2,
                            color: sage,
                          ),
                          onPressed: () => _noteDialog(sel, ch),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

// ───────────────────── الأهداف والإنجازات ─────────────────────

class GoalsScreen extends StatelessWidget {
  final AppStore store;
  const GoalsScreen({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final todayKey = ymd(DateTime.now());
    final dayMins = store.minutesOn(todayKey);
    final weekMins = store.minutesInRange(7);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        pageTitle('الأهداف والإنجازات'),
        const SizedBox(height: 14),
        paper([
          heading('أهدافك', size: 18),
          const SizedBox(height: 8),
          stepper('الهدف اليومي (دقيقة)', store.goalDay, store.setGoalDay, min: 15, max: 720, step: 15),
          mutedText('النهارده: ${fmtMins(dayMins)} من ${fmtMins(store.goalDay)}', size: 14),
          const SizedBox(height: 4),
          progressBar(dayMins / store.goalDay),
          const SizedBox(height: 16),
          stepper('الهدف الأسبوعي (دقيقة)', store.goalWeek, store.setGoalWeek, min: 60, max: 5000, step: 60),
          mutedText('آخر 7 أيام: ${fmtMins(weekMins)} من ${fmtMins(store.goalWeek)}', size: 14),
          const SizedBox(height: 4),
          progressBar(weekMins / store.goalWeek),
        ]),
        const SizedBox(height: 14),
        paper([
          Row(
            children: [
              Icon(Icons.local_fire_department_outlined, color: sage),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'السلسلة الحالية: ${store.streak} يوم · الأطول: ${store.longestStreak}',
                  style: TextStyle(fontSize: 16, color: ink),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          mutedText('اليوم بيتحسب لو سجّلت جلسة تركيز أو علّمت مهمة مكتملة.', size: 13),
        ]),
        const SizedBox(height: 14),
        paper([
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('إظهار الإنجازات في الرئيسية', style: TextStyle(color: ink)),
            value: store.showAch,
            onChanged: store.setShowAch,
          ),
        ]),
        const SizedBox(height: 14),
        for (final g in store.achievements) ...[
          paper([
            Row(
              children: [
                Expanded(child: heading(g.title, size: 17)),
                Text('${g.value} ${g.unit}', style: TextStyle(color: brown)),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final t in g.targets)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: g.value >= t ? leaf : leaf.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      g.value >= t ? '$t ✓' : '$t',
                      style: TextStyle(
                        color: g.value >= t ? onLeaf : ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            if (g.next != null) ...[
              const SizedBox(height: 10),
              progressBar(g.value / g.next!),
              const SizedBox(height: 4),
              mutedText('الهدف الجاي: ${g.next} ${g.unit}', size: 13),
            ],
          ]),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

// ───────────────────── النسخ الاحتياطي ─────────────────────

Future<void> importFlow(BuildContext context, AppStore store) async {
  final c = TextEditingController();
  BackupData? data;
  String? err;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        backgroundColor: card,
        title: Text('استعادة نسخة احتياطية', style: TextStyle(color: ink)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: c,
                maxLines: 6,
                style: TextStyle(color: ink, fontSize: 13),
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  hintText: 'الصق النسخة الاحتياطية هنا',
                  errorText: err,
                  errorMaxLines: 3,
                ),
              ),
              TextButton.icon(
                onPressed: () async {
                  final d = await Clipboard.getData('text/plain');
                  if (d?.text != null) set(() => c.text = d!.text!);
                },
                icon: const Icon(Icons.paste),
                label: const Text('لصق من الحافظة'),
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
              backgroundColor: leaf,
              foregroundColor: onLeaf,
            ),
            onPressed: () {
              try {
                data = decodeBackup(c.text);
                Navigator.pop(ctx, true);
              } on FormatException catch (e) {
                set(() => err = e.message);
              }
            },
            child: const Text('فحص ومتابعة'),
          ),
        ],
      ),
    ),
  );
  final d = data;
  if (ok != true || d == null || !context.mounted) return;
  final yes = await confirmDialog(
    context,
    'استبدال البيانات؟',
    'النسخة فيها ${d.subjects.length} مادة و${d.tasks.length} مهمة و${d.sessions.length} جلسة.\n'
        'بياناتك الحالية (${store.subjects.length} مادة، ${store.tasks.length} مهمة) هتتستبدل، '
        'وهنحتفظ بنسخة أمان منها على الجهاز.',
    yes: 'استبدل',
    danger: true,
  );
  if (!yes) return;
  final saved = await store.applyBackup(d);
  if (context.mounted) {
    snack(context, saved ? 'اتستعادت النسخة الاحتياطية' : 'حصلت مشكلة أثناء الحفظ');
  }
}

class BackupScreen extends StatelessWidget {
  final AppStore store;
  const BackupScreen({super.key, required this.store});

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
    children: [
      pageTitle('النسخ الاحتياطي'),
      const SizedBox(height: 14),
      paper([
        heading('بياناتك الحالية', size: 18),
        const SizedBox(height: 6),
        mutedText(
          '${store.subjects.length} مادة · ${store.tasks.length} مهمة · ${store.sessions.length} جلسة تركيز',
        ),
        const SizedBox(height: 8),
        mutedText(
          'البيانات محفوظة على جهازك بس. لو مسحت التطبيق أو بياناته هتضيع، فخد نسخة احتياطية من وقت للتاني.',
          size: 14,
        ),
      ]),
      const SizedBox(height: 14),
      paper([
        heading('تصدير', size: 18),
        const SizedBox(height: 6),
        mutedText('بننسخ بياناتك كنص. الصقه في ملاحظات أو ابعته لنفسك على واتساب.', size: 14),
        const SizedBox(height: 10),
        primaryButton(
          'انسخ النسخة الاحتياطية',
          () async {
            await Clipboard.setData(ClipboardData(text: store.exportBackup()));
            if (context.mounted) snack(context, 'اتنسخت النسخة. الصقها في مكان آمن');
          },
          icon: Icons.copy,
        ),
      ]),
      const SizedBox(height: 14),
      paper([
        heading('استعادة', size: 18),
        const SizedBox(height: 6),
        mutedText(
          'بنفحص النسخة الأول قبل ما نغيّر أي حاجة، وبنطلب تأكيدك، وبنحتفظ بنسخة أمان من بياناتك الحالية.',
          size: 14,
        ),
        const SizedBox(height: 10),
        softButton(
          'استعادة من نسخة',
          () => importFlow(context, store),
          icon: Icons.restore,
        ),
      ]),
    ],
  );
}
