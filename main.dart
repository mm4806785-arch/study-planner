import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens_main.dart';
import 'screens_more.dart';
import 'store.dart';
import 'ui.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const StudyApp());
}

ThemeData _theme(bool dark) => ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF5B7C63),
    brightness: dark ? Brightness.dark : Brightness.light,
  ),
  scaffoldBackgroundColor: canvasColorFor(dark),
);

class StudyApp extends StatelessWidget {
  const StudyApp({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<ThemeMode>(
    valueListenable: appThemeMode,
    builder: (context, mode, _) => MaterialApp(
      title: 'مساحتك الأكاديمية',
      debugShowCheckedModeBanner: false,
      themeMode: mode,
      theme: _theme(false),
      darkTheme: _theme(true),
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (c, w) =>
          Directionality(textDirection: TextDirection.rtl, child: w!),
      home: const Home(),
    ),
  );
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final store = AppStore();
  int tab = 0; // 0 الرئيسية، 1 الخطة، 2 التايمر، 3 المزيد
  int sub = 0; // صفحة فرعية داخل "المزيد"

  @override
  void initState() {
    super.initState();
    store.addListener(_onStore);
    store.load();
  }

  @override
  void dispose() {
    store.removeListener(_onStore);
    store.dispose();
    super.dispose();
  }

  void _onStore() {
    final e = store.error;
    if (e == null || !mounted) return;
    store.error = null;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e)));
  }

  void go(int t, [int s = 0]) => setState(() {
    tab = t;
    sub = s;
  });

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([store, appThemeMode]),
    builder: (context, _) => PopScope(
      canPop: tab == 0 && sub == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        setState(() {
          if (tab == 3 && sub != 0) {
            sub = 0;
          } else {
            tab = 0;
            sub = 0;
          }
        });
      },
      child: Scaffold(
        backgroundColor: canvas,
        body: SafeArea(
          child: store.loaded
              ? _body()
              : Center(child: CircularProgressIndicator(color: leaf)),
        ),
        bottomNavigationBar: _nav(),
      ),
    ),
  );

  Widget _body() {
    switch (tab) {
      case 0:
        return HomeScreen(store: store, go: go);
      case 1:
        return PlanScreen(store: store, go: go);
      case 2:
        return TimerScreen(store: store, go: go);
      default:
        if (sub == 0) return MoreMenu(go: go);
        return Column(
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                child: TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: sage),
                  onPressed: () => go(3),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('رجوع', style: TextStyle(fontSize: 16)),
                ),
              ),
            ),
            Expanded(child: _sub()),
          ],
        );
    }
  }

  Widget _sub() {
    switch (sub) {
      case 1:
        return SubjectsScreen(store: store, go: go);
      case 2:
        return ProgressScreen(store: store);
      case 3:
        return RevisionScreen(store: store);
      case 4:
        return GoalsScreen(store: store);
      case 5:
        return SetupScreen(store: store, go: go);
      default:
        return BackupScreen(store: store);
    }
  }

  Widget _item(int i, String label, IconData icon) {
    final sel = tab == i;
    final c = sel ? navFg : navFg.withOpacity(0.6);
    return Expanded(
      child: InkWell(
        onTap: () => go(i),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
              decoration: BoxDecoration(
                color: sel ? navFg.withOpacity(0.15) : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: c, size: 24),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: c,
                fontWeight: sel ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _nav() => Container(
    color: navBg,
    child: SafeArea(
      top: false,
      child: SizedBox(
        height: 66,
        child: Row(
          children: [
            _item(0, 'الرئيسية', Icons.home_rounded),
            _item(1, 'الخطة', Icons.calendar_month_rounded),
            Expanded(
              child: Center(
                child: Transform.translate(
                  offset: const Offset(0, -12),
                  child: Breathe(
                    child: Tooltip(
                      message: 'مهمة سريعة',
                      child: GestureDetector(
                        onTap: () => quickAddFlow(context, store),
                        child: Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            color: leaf,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: canvasColorFor(isDark),
                              width: 4,
                            ),
                          ),
                          child: Icon(Icons.add, color: onLeaf, size: 30),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            _item(2, 'التايمر', Icons.timer_rounded),
            _item(3, 'المزيد', Icons.grid_view_rounded),
          ],
        ),
      ),
    ),
  );
}
