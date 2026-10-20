import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'classroom_page.dart';
import 'grades_page.dart';
import 'homework_page.dart';
import 'apple_design.dart';
import 'mirror_service.dart';
import 'rules_page.dart';
import 'schedule_page.dart';
import 'today_page.dart';
import 'src/rust/frb_generated.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await RustLib.init();
    runApp(const GinkgoApp());
  } catch (_) {
    runApp(
      CupertinoApp(
        home: CupertinoPageScaffold(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('本地服务启动失败，请重试'),
                CupertinoButton(onPressed: main, child: const Text('重新启动')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class GinkgoApp extends StatelessWidget {
  const GinkgoApp({
    super.key,
    this.service = const NativeMirrorService(),
    this.brightness,
  });
  final MirrorService service;
  final Brightness? brightness;
  @override
  Widget build(BuildContext context) => CupertinoApp(
    title: 'Ginkgo 银杏',
    debugShowCheckedModeBanner: false,
    locale: const Locale('zh', 'CN'),
    supportedLocales: const [Locale('zh', 'CN')],
    localizationsDelegates: GlobalCupertinoLocalizations.delegates,
    theme: CupertinoThemeData(
      primaryColor: AppleDesign.accent,
      textTheme: const CupertinoTextThemeData(
        textStyle: AppleDesign.body,
        navTitleTextStyle: TextStyle(
          inherit: false,
          fontFamily: AppleDesign.font,
          fontFamilyFallback: AppleDesign.fallback,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: CupertinoColors.label,
        ),
        navLargeTitleTextStyle: AppleDesign.title,
        actionTextStyle: TextStyle(
          inherit: false,
          fontFamily: AppleDesign.font,
          fontFamilyFallback: AppleDesign.fallback,
          fontSize: 17,
          letterSpacing: -0.25,
          color: AppleDesign.accent,
        ),
        dateTimePickerTextStyle: TextStyle(
          inherit: false,
          fontFamily: AppleDesign.font,
          fontFamilyFallback: AppleDesign.fallback,
          fontSize: 21,
          color: CupertinoColors.label,
        ),
      ),
      brightness: brightness,
    ),
    home: LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth >= 760
          ? _DesktopWorkspace(service: service)
          : CupertinoTabScaffold(
              tabBar: CupertinoTabBar(
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(CupertinoIcons.sun_max),
                    label: '今天',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(CupertinoIcons.building_2_fill),
                    label: '空教室',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(CupertinoIcons.calendar),
                    label: '课表',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(CupertinoIcons.doc_text),
                    label: '作业',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(CupertinoIcons.chart_bar_alt_fill),
                    label: '成绩',
                  ),
                ],
              ),
              tabBuilder: (context, index) => switch (index) {
                0 => TodayPage(service: service),
                1 => ClassroomPage(service: service),
                2 => SchedulePage(service: service),
                3 => HomeworkPage(service: service),
                _ => GradesPage(service: service),
              },
            ),
    ),
  );
}

class _DesktopWorkspace extends StatefulWidget {
  const _DesktopWorkspace({required this.service});
  final MirrorService service;
  @override
  State<_DesktopWorkspace> createState() => _DesktopWorkspaceState();
}

class _DesktopWorkspaceState extends State<_DesktopWorkspace> {
  int selected = 0;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 220,
        color: CupertinoColors.systemGroupedBackground.resolveFrom(context),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Ginkgo',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(left: 20, top: 16, bottom: 8),
                child: Text(
                  '校园',
                  style: TextStyle(
                    fontSize: 12,
                    color: CupertinoColors.secondaryLabel,
                  ),
                ),
              ),
              _sidebar('今天', CupertinoIcons.sun_max, 0),
              _sidebar('空教室', CupertinoIcons.building_2_fill, 1),
              _sidebar('课表', CupertinoIcons.calendar, 2),
              _sidebar('作业', CupertinoIcons.doc_text, 3),
              _sidebar('成绩', CupertinoIcons.chart_bar_alt_fill, 4),
              _sidebar('规则示例', CupertinoIcons.checkmark_shield, 5),
              const Spacer(),
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  '离线合成样例',
                  style: TextStyle(
                    fontSize: 12,
                    color: CupertinoColors.secondaryLabel,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      Container(
        width: 0.5,
        color: CupertinoColors.separator.resolveFrom(context),
      ),
      Expanded(
        child: IndexedStack(
          index: selected,
          children: [
            TodayPage(service: widget.service),
            ClassroomPage(service: widget.service),
            SchedulePage(service: widget.service),
            HomeworkPage(service: widget.service),
            GradesPage(service: widget.service),
            RulesPage(service: widget.service),
          ],
        ),
      ),
    ],
  );
  Widget _sidebar(String title, IconData icon, int index) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    child: CupertinoButton(
      padding: const EdgeInsets.all(10),
      color: selected == index
          ? CupertinoColors.tertiarySystemFill.resolveFrom(context)
          : null,
      onPressed: () => setState(() => selected = index),
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 10),
          Text(title, style: const TextStyle(fontSize: 14)),
        ],
      ),
    ),
  );
}
