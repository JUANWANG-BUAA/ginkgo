import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:url_launcher/url_launcher.dart';

import 'apple_design.dart';
import 'apple_widgets.dart';
import 'mirror_service.dart';

/// Official shuttle timetable. Only the published page is shown: the app does
/// not guess live seat counts and never proxies ticketing.
class ShuttlePage extends StatefulWidget {
  const ShuttlePage({super.key, required this.service});
  final MirrorService service;
  @override
  State<ShuttlePage> createState() => _ShuttlePageState();
}

class _ShuttlePageState extends State<ShuttlePage> {
  List<Map<String, dynamic>>? tables;
  String source = '';
  String? error;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await widget.service.shuttleTimetable();
      if (!mounted) return;
      if (result.payload != null && result.failure == null) {
        final payload = jsonDecode(result.payload!) as Map<String, dynamic>;
        setState(() {
          tables = (payload['tables'] as List)
              .cast<Map<String, dynamic>>();
          source = payload['source'] as String? ?? '';
        });
      } else {
        setState(() => error = '时刻表读取未完成，请稍后重试');
      }
    } catch (_) {
      if (mounted) setState(() => error = '时刻表读取未完成，请稍后重试');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> openOfficial() async {
    final uri = Uri.parse(
      source.isEmpty ? 'https://www.buaa.edu.cn/info/1065/1762.htm' : source,
    );
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (opened || !mounted) return;
    await showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('未能打开浏览器'),
        content: Text('请手动访问：\n$uri'),
        actions: [
          CupertinoDialogAction(
            onPressed: () {
              if (ModalRoute.of(context)?.isCurrent ?? false) {
                Navigator.pop(context);
              }
            },
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
      context,
    ),
    navigationBar: CupertinoNavigationBar(
      middle: const Text('校车时刻表'),
      trailing: CupertinoButton(
        padding: EdgeInsets.zero,
        key: const Key('shuttle-refresh'),
        onPressed: busy ? null : load,
        child: busy
            ? const CupertinoActivityIndicator()
            : const Icon(CupertinoIcons.refresh, size: 22),
      ),
    ),
    child: SafeArea(
      child: ListView(
        key: const Key('shuttle-scroll'),
        children: [
          AppleSection(
            footer: const Text(
              '数据来自学校公开时刻表页面，仅作参考。应用不代理购票，也不显示实时余票。',
            ),
            children: [
              AppleListTile(
                key: const Key('shuttle-official'),
                title: const Text('查看官方页面'),
                subtitle: const Text('购票、余票与临时调整以官方为准'),
                leading: const Icon(
                  CupertinoIcons.arrow_up_right_square,
                  color: AppleDesign.resourceBlue,
                ),
                trailing: const CupertinoListTileChevron(),
                onTap: openOfficial,
              ),
            ],
          ),
          if (busy && tables == null)
            const AppleSection(
              children: [
                AppleListTile(
                  title: Text('正在读取官方时刻表…'),
                  leading: CupertinoActivityIndicator(),
                ),
              ],
            ),
          if (error != null)
            AppleSection(children: [AppleListTile(title: Text(error!))]),
          if (tables != null && tables!.isEmpty && !busy)
            const AppleSection(
              children: [
                AppleListTile(
                  title: Text('暂时没有可显示的时刻表'),
                  subtitle: Text('官方页面结构可能已变化，请到官方页面查看。'),
                ),
              ],
            ),
          for (final table in tables ?? const <Map<String, dynamic>>[])
            ..._tableSections(table),
          const SizedBox(height: 24),
        ],
      ),
    ),
  );

  List<Widget> _tableSections(Map<String, dynamic> table) {
    final left = table['left'] as String? ?? '';
    final right = table['right'] as String? ?? '';
    final sections =
        (table['sections'] as List? ?? const []).cast<Map<String, dynamic>>();
    return [
      for (final section in sections)
        AppleSection(
          header: Text(
            (section['label'] as String? ?? '').isEmpty
                ? '$left / $right'
                : '${section['label']} · $left / $right',
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _direction(
                      left,
                      (section['left'] as List? ?? const [])
                          .cast<Map<String, dynamic>>(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _direction(
                      right,
                      (section['right'] as List? ?? const [])
                          .cast<Map<String, dynamic>>(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
    ];
  }

  Widget _direction(String name, List<Map<String, dynamic>> runs) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        name,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 6),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final run in runs)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppleDesign.resourceBlue.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                (run['capacity'] as String? ?? '').isEmpty
                    ? '${run['time']}'
                    : '${run['time']} · ${run['capacity']}座',
                style: const TextStyle(fontSize: 13),
              ),
            ),
        ],
      ),
    ],
  );
}
