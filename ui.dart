// نظام التصميم: ألوان، عناصر مشتركة، رسم بياني بسيط.
import 'dart:math';
import 'package:flutter/material.dart';
import 'store.dart';

bool get isDark => appThemeMode.value == ThemeMode.dark;

Color canvasColorFor(bool dark) =>
    dark ? const Color(0xFF151C18) : const Color(0xFFF5F4EE);

Color get canvas => canvasColorFor(isDark);
Color get ink => isDark ? const Color(0xFFE8EDE8) : const Color(0xFF28352D);
Color get card => isDark ? const Color(0xFF202923) : const Color(0xFFFAF8F2);
Color get navBg => isDark ? const Color(0xFF101713) : const Color(0xFF26392E);
Color get sage => isDark ? const Color(0xFFA4BEA8) : const Color(0xFF4F6F59);
Color get brown => isDark ? const Color(0xFFC8B99F) : const Color(0xFF78664F);
Color get leaf => isDark ? const Color(0xFF70977A) : const Color(0xFF5B7C63);
Color get warn => isDark ? const Color(0xFFE0A38F) : const Color(0xFFB3472F);
const onAccent = Color(0xFFFAF8F2);
Color get onLeaf => isDark ? const Color(0xFF0F1A13) : onAccent;
Color get navFg => isDark ? const Color(0xFFE8EDE8) : onAccent;

// ───────── عناصر عامة ─────────

Widget paper(
  List<Widget> kids, {
  EdgeInsets padding = const EdgeInsets.all(16),
}) => Container(
  width: double.infinity,
  padding: padding,
  decoration: BoxDecoration(
    color: card,
    borderRadius: BorderRadius.circular(22),
  ),
  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: kids),
);

Widget heading(String t, {double size = 21}) => Text(
  t,
  style: TextStyle(fontSize: size, fontWeight: FontWeight.bold, color: ink),
);

Widget pageTitle(String t) => Text(
  t,
  style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: ink),
);

Widget mutedText(String t, {double size = 15}) =>
    Text(t, style: TextStyle(fontSize: size, color: brown, height: 1.4));

Widget emptyState({
  required IconData icon,
  required String text,
  String? action,
  VoidCallback? onAction,
}) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 18),
  child: Center(
    child: Column(
      children: [
        Icon(icon, size: 44, color: sage),
        const SizedBox(height: 10),
        Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: brown, height: 1.5),
        ),
        if (action != null && onAction != null) ...[
          const SizedBox(height: 12),
          primaryButton(action, onAction),
        ],
      ],
    ),
  ),
);

Widget primaryButton(String label, VoidCallback? onTap, {IconData? icon}) {
  final style = FilledButton.styleFrom(
    backgroundColor: leaf,
    foregroundColor: onLeaf,
    disabledBackgroundColor: leaf.withOpacity(0.3),
    minimumSize: const Size(0, 50),
    padding: const EdgeInsets.symmetric(horizontal: 22),
    textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
  );
  if (icon == null) {
    return FilledButton(onPressed: onTap, style: style, child: Text(label));
  }
  return FilledButton.icon(
    onPressed: onTap,
    style: style,
    icon: Icon(icon),
    label: Text(label),
  );
}

Widget softButton(String label, VoidCallback? onTap, {IconData? icon}) =>
    OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon ?? Icons.circle, size: icon == null ? 0 : 20),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: ink,
        side: BorderSide(color: sage.withOpacity(0.6)),
        minimumSize: const Size(0, 46),
        textStyle: const TextStyle(fontSize: 16),
      ),
    );

Widget progressBar(double v, {Color? color, double h = 8}) => ClipRRect(
  borderRadius: BorderRadius.circular(8),
  child: LinearProgressIndicator(
    value: v.clamp(0.0, 1.0).toDouble(),
    minHeight: h,
    color: color ?? leaf,
    backgroundColor: (color ?? leaf).withOpacity(0.16),
  ),
);

Widget statTile(IconData icon, String label, String value) => Expanded(
  child: Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: leaf.withOpacity(0.12),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: sage),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: ink,
          ),
        ),
        Text(label, style: TextStyle(fontSize: 13, color: brown)),
      ],
    ),
  ),
);

Widget stepper(
  String label,
  int value,
  void Function(int) on, {
  int min = 0,
  int max = 999,
  int step = 1,
  bool enabled = true,
}) => Row(
  children: [
    Expanded(
      child: Text(label, style: TextStyle(fontSize: 16, color: ink)),
    ),
    IconButton(
      onPressed: enabled && value - step >= min ? () => on(value - step) : null,
      icon: const Icon(Icons.remove_circle_outline),
      color: leaf,
      iconSize: 30,
    ),
    SizedBox(
      width: 44,
      child: Text(
        '$value',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ink),
      ),
    ),
    IconButton(
      onPressed: enabled && value + step <= max ? () => on(value + step) : null,
      icon: const Icon(Icons.add_circle_outline),
      color: leaf,
      iconSize: 30,
    ),
  ],
);

void snack(BuildContext context, String text) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(content: Text(text)));
}

Future<bool> confirmDialog(
  BuildContext context,
  String title,
  String body, {
  String yes = 'تأكيد',
  bool danger = false,
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: card,
      title: Text(title, style: TextStyle(color: ink)),
      content: Text(body, style: TextStyle(color: ink, height: 1.5)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: danger ? const Color(0xFFB3472F) : leaf,
            foregroundColor: danger ? onAccent : onLeaf,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(yes),
        ),
      ],
    ),
  );
  return r == true;
}

// ───────── رسم بياني بسيط ─────────

class BarChart extends StatelessWidget {
  final List<int> values;
  final List<String> labels;
  final int highlight;
  final double height;
  final String unit;
  const BarChart({
    super.key,
    required this.values,
    required this.labels,
    this.highlight = -1,
    this.height = 150,
    this.unit = 'د',
  });

  @override
  Widget build(BuildContext context) {
    final top = values.fold<int>(1, (a, b) => a > b ? a : b);
    final barArea = height - 52;
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      values[i] > 0 ? '${values[i]}' : '',
                      style: TextStyle(fontSize: 11, color: brown),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      height: max(3.0, barArea * values[i] / top),
                      decoration: BoxDecoration(
                        color: i == highlight ? leaf : leaf.withOpacity(0.45),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 28,
                      child: Text(
                        labels[i],
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: i == highlight ? ink : brown,
                          fontWeight: i == highlight
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ───────── زخرفة الفرع + نبض الزرار (من النسخة الأصلية) ─────────

class LeafBranch extends StatelessWidget {
  const LeafBranch({super.key});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 130,
    height: 130,
    child: CustomPaint(painter: BranchPainter(sage)),
  );
}

class BranchPainter extends CustomPainter {
  final Color color;
  BranchPainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final stem = Paint()
      ..color = color.withOpacity(0.55)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final p = Path()
      ..moveTo(size.width * 0.9, size.height * 0.1)
      ..quadraticBezierTo(
        size.width * 0.55,
        size.height * 0.45,
        size.width * 0.12,
        size.height * 0.9,
      );
    canvas.drawPath(p, stem);
    final leafPaint = Paint()..color = color.withOpacity(0.35);
    for (var i = 0; i < 5; i++) {
      final t = (i + 1) / 6;
      final x = size.width * (0.9 - 0.78 * t);
      final y = size.height * (0.1 + 0.8 * t);
      final side = i.isEven ? 1.0 : -1.0;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(side * pi / 3);
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(0, -10), width: 12, height: 24),
        leafPaint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(BranchPainter old) => old.color != color;
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
    duration: const Duration(seconds: 3),
  )..repeat(reverse: true);
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(
    scale: Tween(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: c, curve: Curves.easeInOut),
    ),
    child: widget.child,
  );
}

Widget choice(String label, bool sel, VoidCallback? on) => ChoiceChip(
  label: Text(label),
  selected: sel,
  onSelected: on == null ? null : (_) => on(),
  selectedColor: leaf,
  backgroundColor: leaf.withOpacity(0.12),
  labelStyle: TextStyle(
    color: sel ? onLeaf : ink,
    fontWeight: FontWeight.w600,
  ),
  side: BorderSide.none,
  showCheckmark: false,
);
