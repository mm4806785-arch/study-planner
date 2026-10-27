// الشاشات الأساسية: الرئيسية، الخطة، التايمر + أدوات المهام.
import 'package:flutter/material.dart';
import 'logic.dart';
import 'store.dart';
import 'ui.dart';

typedef GoFn = void Function(int tab, [int sub]);

// ───────────────────── أدوات المهام ─────────────────────

Widget taskRow(BuildContext context, AppStore store, Task t) => InkWell(
  onTap: () => store.toggleTask(t),
  onLongPress: () => showTaskMenu(context, store, t),
  child: Padding(
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
    child: Row(
      children: [
        Icon(
          t.done ? Icons.check_circle : Icons.circle_outlined,
          color: t.done ? leaf : sage,
          size: 26,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${t.subject} — ${t.title}',
                style: TextStyle(
                  fontSize: 16,
                  color: ink,
                  decoration: t.done ? TextDecoration.lineThrough : null,
                ),
              ),
              if (t.start != null)
                Text(
                  '${fmtTime(t.start!)} – ${fmtTime(t.start! + t.mins)}',
                  style: TextStyle(fontSize: 13, color: brown),
                ),
            ],
          ),
        ),
        Text('${t.mins} د', style: TextStyle(fontSize: 14, color: brown)),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: Icon(Icons.more_vert, color: sage),
          onPressed: () => showTaskMenu(context, store, t),
        ),
      ],
    ),
  ),
);

Future<void> showTaskMenu(BuildContext context, AppStore store, Task t) async {
  final act = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: card,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(Icons.edit, color: leaf),
            title: Text('تعديل المهمة', style: TextStyle(color: ink)),
            onTap: () => Navigator.pop(ctx, 'edit'),
          ),
          ListTile(
            leading: Icon(Icons.delete_outline, color: warn),
            title: Text('حذف المهمة', style: TextStyle(color: ink)),
            onTap: () => Navigator.pop(ctx, 'del'),
          ),
        ],
      ),
    ),
  );
  if (act == null || !context.mounted) return;
  if (act == 'edit') {
    await editTaskDialog(context, store, t);
  } else if (act == 'del') {
    final i = store.removeTask(t);
    final m = ScaffoldMessenger.of(context);
    m.hideCurrentSnackBar();
    m.showSnackBar(
      SnackBar(
        content: const Text('اتحذفت المهمة'),
        action: SnackBarAction(
          label: 'تراجع',
          onPressed: () => store.restoreTask(i, t),
        ),
      ),
    );
  }
}

Future<void> editTaskDialog(
  BuildContext context,
  AppStore store,
  Task t,
) async {
  final title = TextEditingController(text: t.title);
  var date = DateTime.tryParse(t.date) ?? DateTime.now();
  var mins = t.mins;
  int? start = t.start;
  String? err;
  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        backgroundColor: card,
        title: Text('تعديل المهمة', style: TextStyle(color: ink)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: title,
                style: TextStyle(color: ink),
                decoration: const InputDecoration(labelText: 'اسم المهمة'),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.event, color: leaf),
                title: Text(ymd(date), style: TextStyle(color: ink)),
                subtitle: Text(
                  dayName(ymd(date)),
                  style: TextStyle(color: brown),
                ),
                onTap: () async {
                  final d = await showDatePicker(
                    context: ctx,
                    initialDate: date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (d != null) {
                    set(() {
                      date = d;
                      err = null;
                    });
                  }
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.schedule, color: leaf),
                title: Text(
                  start == null
                      ? 'من غير وقت محدد'
                      : '${fmtTime(start!)} – ${fmtTime(start! + mins)}',
                  style: TextStyle(color: ink),
                ),
                trailing: start == null
                    ? null
                    : IconButton(
                        icon: Icon(Icons.close, color: sage),
                        onPressed: () => set(() {
                          start = null;
                          err = null;
                        }),
                      ),
                onTap: () async {
                  final base = start ?? 16 * 60;
                  final r = await showTimePicker(
                    context: ctx,
                    initialTime: TimeOfDay(
                      hour: (base ~/ 60) % 24,
                      minute: base % 60,
                    ),
                  );
                  if (r != null) {
                    set(() {
                      start = r.hour * 60 + r.minute;
                      err = null;
                    });
                  }
                },
              ),
              stepper(
                'المدة بالدقايق',
                mins,
                (v) => set(() {
                  mins = v;
                  err = null;
                }),
                min: 5,
                max: 240,
                step: 5,
              ),
              if (err != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
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
              final name = title.text.trim();
              if (name.isEmpty) {
                set(() => err = 'اكتب اسم المهمة');
                return;
              }
              final c = store.conflictWith(t.id, ymd(date), start, mins);
              if (c != null) {
                set(
                  () => err =
                      'بيتعارض مع «${c.title}» الساعة ${fmtTime(c.start!)}. غيّر الوقت أو المدة.',
                );
                return;
              }
              store.updateTask(
                t,
                title: name,
                date: ymd(date),
                mins: mins,
                start: start,
              );
              Navigator.pop(ctx);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    ),
  );
}

Future<void> quickAddFlow(BuildContext context, AppStore store) async {
  final c = TextEditingController();
  final text = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: card,
      title: Text('مهمة سريعة', style: TextStyle(color: ink)),
      content: TextField(
        controller: c,
        autofocus: true,
        style: TextStyle(color: ink),
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
  if (text != null && text.trim().isNotEmpty) store.addQuick(text.trim());
}

/// توليد/إعادة توزيع الخطة مع تأكيد. يرجّع true لو اتنفّذت.
Future<bool> generateFlow(BuildContext context, AppStore store) async {
  if (store.subjects.isEmpty) {
    snack(context, 'ضيف مادة واحدة على الأقل الأول');
    return false;
  }
  final n = store.undoneGenerated;
  if (n > 0) {
    final ok = await confirmDialog(
      context,
      'إعادة توزيع الخطة',
      'هيتعاد توزيع $n مهمة لسه ما اتعملتش (بما فيها الفايتة). '
          'المهام المخلّصة والإضافية هتفضل زي ما هي.',
      yes: 'أعد التوزيع',
    );
    if (!ok) return false;
  }
  store.regenerate();
  if (context.mounted) {
    snack(
      context,
      store.overflow > 0
          ? 'اتولّدت الخطة، بس فيه ${store.overflow} شابتر زيادة عن الوقت المتاح'
          : 'اتولّدت الخطة',
    );
  }
  return true;
}

// ───────────────────── الرئيسية ─────────────────────

class HomeScreen extends StatelessWidget {
  final AppStore store;
  final GoFn go;
  const HomeScreen({super.key, required this.store, required this.go});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = dayOnly(now);
    final todayKey = ymd(now);
    final list = store.tasksOn(todayKey);
    final upcoming = store.subjects
        .where((s) => daysBetween(today, s.exam) >= 0)
        .toList()
      ..sort((a, b) => a.exam.compareTo(b.exam));
    final sorted = [...store.subjects]
      ..sort((a, b) => a.exam.compareTo(b.exam));
    final allPast = store.subjects.isNotEmpty && upcoming.isEmpty;
    final nearest = upcoming.isEmpty
        ? null
        : daysBetween(today, upcoming.first.exam);
    final todayMins = list.fold<int>(0, (a, t) => a + t.mins);
    final todayDoneMins = list
        .where((t) => t.done)
        .fold<int>(0, (a, t) => a + t.mins);
    final studied = store.minutesOn(todayKey);
    final next = store.nextTask;
    final overdue = store.overdueTasks;
    final missed = store.missedCount;
    final cw = (MediaQuery.of(context).size.width - 40 - 12) / 2;

    String sub;
    if (store.subjects.isEmpty) {
      sub = 'ضيف موادك وتواريخ امتحاناتك وابدأ';
    } else if (allPast) {
      sub = 'كل الامتحانات عدّى موعدها';
    } else if (nearest == 0) {
      sub = 'امتحانك النهارده، بالتوفيق!';
    } else {
      sub = 'فاضل $nearest يوم على أقرب امتحان';
    }

    AchGroup? nextAch;
    var bestRatio = -1.0;
    for (final g in store.achievements) {
      final n = g.next;
      if (n == null) continue;
      final r = g.value / n;
      if (r > bestRatio) {
        bestRatio = r;
        nextAch = g;
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Stack(
          children: [
            Positioned(
              left: -20,
              top: -10,
              child: Opacity(opacity: 0.6, child: const LeafBranch()),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: pageTitle('مساحتك الأكاديمية')),
                    IconButton(
                      tooltip: 'تغيير المظهر',
                      onPressed: store.toggleTheme,
                      icon: Icon(
                        isDark ? Icons.light_mode : Icons.dark_mode,
                        color: sage,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                mutedText(sub, size: 17),
                const SizedBox(height: 22),
              ],
            ),
          ],
        ),
        if (store.subjects.isEmpty)
          paper([
            emptyState(
              icon: Icons.menu_book_outlined,
              text:
                  'لسه ما ضفتش مواد.\nضيف أول مادة وتاريخ امتحانها وهنعملك خطة مذاكرة.',
              action: 'أضف أول مادة',
              onAction: () => go(3, 1),
            ),
          ])
        else ...[
          if (missed > 0) ...[
            paper([
              Row(
                children: [
                  Icon(Icons.history, color: warn),
                  const SizedBox(width: 8),
                  Expanded(
                    child: heading('فاتك $missed مهمة', size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              mutedText(
                'تحب نقترح جدول جديد يوزّعهم على الأيام اللي فاضلة قبل الامتحان؟',
              ),
              const SizedBox(height: 10),
              primaryButton(
                'اقترح جدول جديد',
                () => generateFlow(context, store),
                icon: Icons.auto_awesome,
              ),
            ]),
            const SizedBox(height: 14),
          ],
          if (store.overflow > 0) ...[
            paper([
              Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: warn),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'الوقت مش كفاية: فيه ${store.overflow} شابتر زيادة. زوّد ساعات المذاكرة في الإعداد.',
                      style: TextStyle(color: ink, fontSize: 15, height: 1.4),
                    ),
                  ),
                ],
              ),
            ]),
            const SizedBox(height: 14),
          ],
          paper([
            heading('تقدّم النهارده'),
            const SizedBox(height: 12),
            Row(
              children: [
                statTile(Icons.timer_outlined, 'ذاكرت النهارده', fmtMins(studied)),
                const SizedBox(width: 10),
                statTile(
                  Icons.hourglass_bottom,
                  'إجمالي الوقت',
                  fmtMins(store.totalMinutes),
                ),
                const SizedBox(width: 10),
                statTile(
                  Icons.local_fire_department_outlined,
                  'السلسلة',
                  '${store.streak} يوم',
                ),
              ],
            ),
            const SizedBox(height: 14),
            mutedText(
              'الهدف اليومي: ${fmtMins(studied)} من ${fmtMins(store.goalDay)}',
            ),
            const SizedBox(height: 6),
            progressBar(studied / store.goalDay),
            if (list.isNotEmpty) ...[
              const SizedBox(height: 12),
              mutedText(
                'خطة النهارده: خلّصت $todayDoneMins من $todayMins دقيقة',
              ),
              const SizedBox(height: 6),
              progressBar(todayMins == 0 ? 0 : todayDoneMins / todayMins),
            ],
            const SizedBox(height: 16),
            primaryButton(
              next == null
                  ? 'مفيش جلسة جاية'
                  : (store.timerStarted
                        ? 'كمّل الجلسة الحالية'
                        : 'ابدأ الجلسة التالية: ${next.subject}'),
              next == null && !store.timerStarted
                  ? null
                  : () {
                      if (!store.timerStarted && next != null) {
                        store.startSessionFor(next);
                      }
                      go(2);
                    },
              icon: Icons.play_arrow_rounded,
            ),
          ]),
          const SizedBox(height: 14),
          paper([
            heading('خطة النهارده'),
            const SizedBox(height: 6),
            if (store.tasks.isEmpty)
              emptyState(
                icon: Icons.event_note_outlined,
                text: 'لسه مفيش خطة. ولّدها من موادك وتواريخ الامتحانات.',
                action: 'ولّد الخطة',
                onAction: () => generateFlow(context, store),
              )
            else if (list.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: mutedText('مفيش مهام النهارده. خد راحتك!', size: 16),
              )
            else
              ...list.map((t) => taskRow(context, store, t)),
          ]),
          if (overdue.isNotEmpty) ...[
            const SizedBox(height: 14),
            paper([
              heading('مهام متأخرة (${overdue.length})', size: 19),
              const SizedBox(height: 6),
              ...overdue.take(6).map((t) => taskRow(context, store, t)),
              if (overdue.length > 6)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: mutedText(
                    'و ${overdue.length - 6} مهمة تانية في تبويب «الخطة»',
                  ),
                ),
            ]),
          ],
          if (upcoming.isNotEmpty) ...[
            const SizedBox(height: 14),
            paper([
              heading('الامتحانات القادمة'),
              const SizedBox(height: 10),
              ...upcoming.take(4).map((s) {
                final done = store.doneOf(s);
                final left = s.total - done;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              s.name,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: ink,
                              ),
                            ),
                          ),
                          Text(
                            examLabel(s.exam),
                            style: TextStyle(fontSize: 14, color: brown),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      progressBar(s.total == 0 ? 0 : done / s.total),
                      const SizedBox(height: 4),
                      Text(
                        left == 0
                            ? 'خلّصت كل ${s.label}ات'
                            : 'متبقي $left من ${s.total}',
                        style: TextStyle(fontSize: 13, color: brown),
                      ),
                    ],
                  ),
                );
              }),
            ]),
          ],
          const SizedBox(height: 22),
          heading('المواد'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final s in sorted)
                InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () => go(3, 3),
                  child: Container(
                    width: cw,
                    height: 122,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: leaf,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: onLeaf,
                          ),
                        ),
                        Text(
                          examLabel(s.exam),
                          style: TextStyle(
                            fontSize: 13,
                            color: onLeaf.withOpacity(0.85),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${store.doneOf(s)} / ${s.total}  ·  ${s.total == 0 ? 0 : (store.doneOf(s) * 100 / s.total).round()}%',
                          style: TextStyle(fontSize: 14, color: onLeaf),
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: s.total == 0 ? 0 : store.doneOf(s) / s.total,
                            minHeight: 5,
                            color: onLeaf,
                            backgroundColor: onLeaf.withOpacity(0.25),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          if (store.showAch && nextAch != null) ...[
            const SizedBox(height: 14),
            paper([
              Row(
                children: [
                  Icon(Icons.emoji_events_outlined, color: sage),
                  const SizedBox(width: 8),
                  Expanded(child: heading('الإنجاز الجاي', size: 18)),
                  TextButton(
                    onPressed: () => go(3, 4),
                    child: const Text('كل الإنجازات'),
                  ),
                ],
              ),
              mutedText(
                '${nextAch.title}: ${nextAch.value} من ${nextAch.next} ${nextAch.unit}',
              ),
              const SizedBox(height: 6),
              progressBar(nextAch.value / nextAch.next!),
            ]),
          ],
        ],
      ],
    );
  }
}

// ───────────────────── الخطة ─────────────────────

class PlanScreen extends StatelessWidget {
  final AppStore store;
  final GoFn go;
  const PlanScreen({super.key, required this.store, required this.go});

  @override
  Widget build(BuildContext context) {
    final todayKey = ymd(DateTime.now());
    final by = <String, List<Task>>{};
    for (final t in store.tasks) {
      by.putIfAbsent(t.date, () => <Task>[]).add(t);
    }
    final days = by.keys.toList()..sort();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        pageTitle('الخطة'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            primaryButton(
              'أعد توزيع الخطة',
              () => generateFlow(context, store),
              icon: Icons.auto_awesome,
            ),
            softButton(
              'مهمة جديدة',
              () => quickAddFlow(context, store),
              icon: Icons.add,
            ),
          ],
        ),
        if (store.tasks.isNotEmpty) ...[
          const SizedBox(height: 10),
          mutedText(
            'اضغط على المهمة لتعليمها مكتملة، واضغط ⋮ (أو اضغط مطوّلاً) للتعديل أو الحذف.',
            size: 14,
          ),
        ],
        if (store.overflow > 0) ...[
          const SizedBox(height: 10),
          Text(
            'تنبيه: ${store.overflow} شابتر زيادة عن الوقت المتاح قبل الامتحان.',
            style: TextStyle(color: warn, fontSize: 15),
          ),
        ],
        const SizedBox(height: 14),
        if (store.tasks.isEmpty)
          paper([
            emptyState(
              icon: Icons.calendar_month_outlined,
              text: store.subjects.isEmpty
                  ? 'ضيف مواد الأول وبعدين ولّد الخطة.'
                  : 'لسه مفيش خطة. دوس «أعد توزيع الخطة».',
              action: store.subjects.isEmpty ? 'أضف مادة' : null,
              onAction: store.subjects.isEmpty ? () => go(3, 1) : null,
            ),
          ])
        else
          for (final d in days) ...[
            paper([
              Text(
                '${dayName(d)} $d${d == todayKey ? ' (النهارده)' : ''}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: d.compareTo(todayKey) < 0 &&
                          by[d]!.any((t) => !t.done)
                      ? warn
                      : ink,
                ),
              ),
              Text(
                '${by[d]!.where((t) => t.done).length} من ${by[d]!.length} مكتملة · ${fmtMins(by[d]!.fold<int>(0, (a, t) => a + t.mins))}',
                style: TextStyle(fontSize: 13, color: brown),
              ),
              const SizedBox(height: 4),
              ...by[d]!.map((t) => taskRow(context, store, t)),
            ]),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}

// ───────────────────── التايمر ─────────────────────

class TimerScreen extends StatelessWidget {
  final AppStore store;
  final GoFn go;
  const TimerScreen({super.key, required this.store, required this.go});

  @override
  Widget build(BuildContext context) {
    final running = store.timerRunning;
    final started = store.timerStarted;
    final isFocus = store.phase == Phase.focus;
    final total = store.phaseSeconds;
    final frac = started ? 1 - store.remaining / total : 0.0;
    final mm = (store.remaining ~/ 60).toString().padLeft(2, '0');
    final ss = (store.remaining % 60).toString().padLeft(2, '0');
    final ringColor = isFocus ? leaf : brown;
    final todayKey = ymd(DateTime.now());

    final selectable = store.tasks
        .where(
          (t) =>
              !t.done &&
              (store.timerSubjectId == null ||
                  store.subjectByName(t.subject)?.id == store.timerSubjectId),
        )
        .take(40)
        .toList();
    final dropValue = selectable.any((t) => t.id == store.timerTaskId)
        ? store.timerTaskId
        : null;
    final last = store.lastSession;
    final lastTask = store.taskById(last?.taskId);
    final todaySessions = store.sessions.where((s) => s.date == todayKey).length;
    final recent = store.sessions.reversed.take(6).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        pageTitle('التايمر'),
        const SizedBox(height: 4),
        mutedText(isFocus ? 'جلسة تركيز (بومودورو)' : 'وقت راحة، خد نفس'),
        const SizedBox(height: 18),
        Center(
          child: SizedBox(
            width: 250,
            height: 250,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 250,
                  height: 250,
                  child: CircularProgressIndicator(
                    value: frac.clamp(0.0, 1.0).toDouble(),
                    strokeWidth: 12,
                    color: ringColor,
                    backgroundColor: ringColor.withOpacity(0.15),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$mm:$ss',
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                        fontSize: 58,
                        fontWeight: FontWeight.bold,
                        color: ink,
                      ),
                    ),
                    Text(
                      isFocus ? 'تركيز' : 'راحة',
                      style: TextStyle(fontSize: 18, color: brown),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: [
            if (!running)
              primaryButton(
                started
                    ? 'استكمال'
                    : (isFocus ? 'ابدأ التركيز' : 'ابدأ الراحة'),
                store.startTimer,
                icon: Icons.play_arrow_rounded,
              )
            else
              primaryButton(
                'إيقاف مؤقت',
                store.pauseTimer,
                icon: Icons.pause_rounded,
              ),
            if (started)
              softButton('إعادة', store.resetTimer, icon: Icons.restart_alt),
            if (started && isFocus)
              softButton('إنهاء وتسجيل', () {
                final before = store.sessions.length;
                store.finishEarly();
                snack(
                  context,
                  store.sessions.length > before
                      ? 'اتسجّلت الجلسة'
                      : 'الوقت أقل من دقيقة فمتسجّلش',
                );
              }, icon: Icons.check),
            if (!isFocus)
              softButton('تخطّي الراحة', store.skipBreak, icon: Icons.skip_next),
          ],
        ),
        const SizedBox(height: 18),
        if (last != null) ...[
          paper([
            Row(
              children: [
                Icon(Icons.check_circle, color: leaf),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'اتسجّلت جلسة ${last.mins} دقيقة — ${last.subject}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: ink,
                    ),
                  ),
                ),
              ],
            ),
            if (lastTask != null && !lastTask.done) ...[
              const SizedBox(height: 8),
              mutedText('خلّصت «${lastTask.title}»؟'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                children: [
                  primaryButton('أيوه، علّمها مكتملة', () {
                    store.toggleTask(lastTask);
                    store.dismissLastSession();
                  }),
                  softButton('لسه', store.dismissLastSession),
                ],
              ),
            ] else
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: store.dismissLastSession,
                  child: const Text('تمام'),
                ),
              ),
          ]),
          const SizedBox(height: 14),
        ],
        paper([
          heading('بتذاكر إيه؟', size: 18),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              choice(
                'عام',
                store.timerSubjectId == null,
                started ? null : () => store.selectSubject(null),
              ),
              for (final s in store.subjects)
                choice(
                  s.name,
                  store.timerSubjectId == s.id,
                  started ? null : () => store.selectSubject(s.id),
                ),
            ],
          ),
          const SizedBox(height: 10),
          DropdownButton<String?>(
            isExpanded: true,
            value: dropValue,
            dropdownColor: card,
            style: TextStyle(color: ink, fontSize: 16),
            hint: Text('اختار مهمة (اختياري)', style: TextStyle(color: brown)),
            items: [
              DropdownMenuItem<String?>(
                value: null,
                child: Text('بدون مهمة محددة', style: TextStyle(color: ink)),
              ),
              for (final t in selectable)
                DropdownMenuItem<String?>(
                  value: t.id,
                  child: Text(
                    '${t.subject} — ${t.title} (${t.date})',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: ink),
                  ),
                ),
            ],
            onChanged: started
                ? null
                : (id) => store.selectTask(store.taskById(id)),
          ),
        ]),
        const SizedBox(height: 14),
        paper([
          heading('مدد الجلسات', size: 18),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final p in const [
                [25, 5],
                [50, 10],
                [90, 15],
              ])
                choice(
                  '${p[0]} / ${p[1]}',
                  store.focusMin == p[0] && store.breakMin == p[1],
                  started
                      ? null
                      : () {
                          store.setFocusMin(p[0]);
                          store.setBreakMin(p[1]);
                        },
                ),
            ],
          ),
          const SizedBox(height: 6),
          stepper(
            'مدة التركيز (دقيقة)',
            store.focusMin,
            store.setFocusMin,
            min: 5,
            max: 120,
            step: 5,
            enabled: !started,
          ),
          stepper(
            'مدة الراحة (دقيقة)',
            store.breakMin,
            store.setBreakMin,
            min: 1,
            max: 30,
            enabled: !started,
          ),
        ]),
        const SizedBox(height: 14),
        paper([
          heading('سجل الجلسات', size: 18),
          const SizedBox(height: 4),
          mutedText(
            'النهارده: $todaySessions جلسة · ${fmtMins(store.minutesOn(todayKey))}',
          ),
          const SizedBox(height: 8),
          if (recent.isEmpty)
            mutedText('لسه ما سجّلتش أي جلسة. ابدأ أول جلسة تركيز!')
          else
            ...recent.map(
              (s) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(Icons.timer_outlined, size: 18, color: sage),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${s.subject} · ${s.date}',
                        style: TextStyle(color: ink, fontSize: 15),
                      ),
                    ),
                    Text(fmtMins(s.mins), style: TextStyle(color: brown)),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          mutedText(
            'التايمر بيحسب الوقت الحقيقي حتى لو قفلت الشاشة، لكن مفيش إشعار صوتي في الخلفية. افتح التطبيق وهيتسجّل اللي خلص.',
            size: 13,
          ),
        ]),
      ],
    );
  }
}
