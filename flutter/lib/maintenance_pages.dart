import 'package:flutter/cupertino.dart';

import 'apple_design.dart';
import 'apple_widgets.dart';
import 'maintenance_service.dart';
import 'mirror_service.dart';

String _time(DateTime date) =>
    '${date.month}月${date.day}日 '
    '${date.hour.toString().padLeft(2, '0')}:'
    '${date.minute.toString().padLeft(2, '0')}（本机时间）';

class MaintenanceScaffold extends StatelessWidget {
  const MaintenanceScaffold({
    super.key,
    required this.title,
    required this.children,
    this.onRefresh,
    this.busy = false,
  });
  final String title;
  final List<Widget> children;
  final Future<void> Function()? onRefresh;
  final bool busy;
  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
      context,
    ),
    child: CustomScrollView(
      key: ValueKey('maintenance-$title'),
      slivers: [
        CupertinoSliverNavigationBar(largeTitle: Text(title), border: null),
        if (onRefresh != null)
          CupertinoSliverRefreshControl(onRefresh: onRefresh),
        SliverList.list(children: [...children, const SizedBox(height: 96)]),
      ],
    ),
  );
}

class SoftwareUpdatePage extends StatefulWidget {
  const SoftwareUpdatePage({super.key, required this.service});
  final MaintenanceService service;
  @override
  State<SoftwareUpdatePage> createState() => _SoftwareUpdatePageState();
}

class _SoftwareUpdatePageState extends State<SoftwareUpdatePage> {
  InstalledVersion? installed;
  UpdateResult? result;
  DateTime? checkedAt;
  String? error;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    _version();
  }

  Future<void> _version() async {
    try {
      final value = await widget.service.version();
      if (mounted) setState(() => installed = value);
    } catch (_) {
      if (mounted) setState(() => error = '无法读取本机版本，请重试');
    }
  }

  Future<void> check() async {
    if (busy || !widget.service.supportsUpdates) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final version = installed ?? await widget.service.version();
      final next = await widget.service.checkUpdate(version.version);
      if (!mounted) return;
      setState(() {
        installed = version;
        result = next;
        checkedAt = DateTime.now();
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              '未能完成更新检查。请检查网络，或稍后重试；GitHub 也可能暂时限流。'
              '${result == null ? '' : '下方保留上次检查结果。'}',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> open() async {
    try {
      if (await widget.service.openReleases(result?.pageUrl)) return;
    } catch (_) {
      /* Explain failure without exposing platform exception. */
    }
    if (mounted) setState(() => error = '无法打开浏览器，请稍后重试');
  }

  Future<void> download(bool accelerated) async {
    final url = result?.downloadUrl;
    if (url == null) return;
    try {
      if (await widget.service.openDownload(url, accelerated: accelerated)) {
        return;
      }
    } catch (_) {
      // Do not expose platform exception text or upstream URLs.
    }
    if (mounted) setState(() => error = '无法打开下载链接，请稍后重试');
  }

  @override
  Widget build(BuildContext context) => MaintenanceScaffold(
    title: '软件更新',
    busy: busy,
    onRefresh: widget.service.supportsUpdates ? check : null,
    children: [
      AppleSection(
        header: const Text('Ginkgo · Android'),
        footer: const Text(
          '从项目 GitHub Releases 检查 Android 版本。Alpha 版本包含预发布更新；正式版仅检查正式发布。',
        ),
        children: [
          AppleListTile(
            leading: const Icon(
              CupertinoIcons.leaf_arrow_circlepath,
              color: AppleDesign.accent,
            ),
            title: const Text('当前安装版本'),
            subtitle: Text(installed?.label ?? '读取中…'),
          ),
          if (widget.service.supportsUpdates)
            AppleListTile(
              title: Text(busy ? '正在检查…' : '检查更新'),
              leading: const Icon(
                CupertinoIcons.arrow_down_circle,
                color: AppleDesign.accent,
              ),
              trailing: busy
                  ? const CupertinoActivityIndicator()
                  : const CupertinoListTileChevron(),
              onTap: busy ? null : check,
            )
          else
            const AppleListTile(title: Text('此平台暂未接入更新检查')),
        ],
      ),
      if (error != null)
        AppleSection(
          children: [
            AppleListTile(
              leading: const Icon(
                CupertinoIcons.exclamationmark_circle,
                color: CupertinoColors.systemOrange,
              ),
              title: Text(error!),
            ),
          ],
        ),
      if (result != null)
        AppleSection(
          header: const Text('检查结果'),
          footer: Text('上次成功检查：${_time(checkedAt!)}'),
          children: [
            AppleListTile(
              title: Text(result!.headline),
              subtitle: Text(
                result!.latest == null
                    ? '项目现有 macOS 发布不适用于 Android。'
                    : 'Android ${result!.latest}',
              ),
            ),
            if (result!.notes?.trim().isNotEmpty ?? false)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    result!.notes!,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: CupertinoColors.secondaryLabel.resolveFrom(
                        context,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      if (result?.downloadUrl != null)
        AppleSection(
          header: const Text('下载安装包'),
          footer: const Text(
            '第三方加速经 gh-proxy.com 下载，仅用于 GitHub 公开安装包。安装由 Android 系统确认；可在发布页核对 SHA-256。',
          ),
          children: [
            AppleListTile(
              leading: const Icon(
                CupertinoIcons.arrow_down_circle,
                color: AppleDesign.accent,
              ),
              title: const Text('GitHub 下载 APK'),
              trailing: const Icon(CupertinoIcons.arrow_up_right, size: 18),
              onTap: () => download(false),
            ),
            AppleListTile(
              leading: const Icon(
                CupertinoIcons.bolt,
                color: CupertinoColors.activeBlue,
              ),
              title: const Text('第三方加速下载'),
              subtitle: const Text('gh-proxy.com'),
              trailing: const Icon(CupertinoIcons.arrow_up_right, size: 18),
              onTap: () => download(true),
            ),
          ],
        ),
      AppleSection(
        header: const Text('发布来源'),
        footer: const Text(
          '在浏览器中下载 APK，再由 Android 系统确认安装。应用不会自动下载或安装；没有 Android 安装包时，不会把 macOS 包标为可更新。',
        ),
        children: [
          AppleListTile(
            title: const Text('前往 GitHub 发布页'),
            subtitle: const Text('JUANWANG-BUAA / ginkgo'),
            trailing: const Icon(CupertinoIcons.arrow_up_right, size: 18),
            onTap: open,
          ),
        ],
      ),
    ],
  );
}

enum _CheckStatus { waiting, running, passed, failed, skipped }

class DiagnosticsPage extends StatefulWidget {
  const DiagnosticsPage({
    super.key,
    required this.service,
    required this.mirror,
  });
  final MaintenanceService service;
  final MirrorService mirror;
  @override
  State<DiagnosticsPage> createState() => _DiagnosticsPageState();
}

class _DiagnosticsPageState extends State<DiagnosticsPage> {
  static const titles = ['Rust 组件', '本地数据目录', '系统安全存储', '图书馆公开服务'];
  static const details = [
    '通过合成课表验证桥接与解析',
    '临时文件写入、读回并删除',
    '独立合成条目写入、读回并删除，不读取账号密码',
    '强制读取公开统计，缓存结果不算连通成功',
  ];
  final states = List.filled(4, _CheckStatus.waiting);
  bool busy = false;
  DateTime? finishedAt;
  Future<void> run({bool network = false}) async {
    if (busy) return;
    setState(() {
      busy = true;
      finishedAt = null;
      for (var i = 0; i < states.length; i++) {
        states[i] = _CheckStatus.waiting;
      }
    });
    final checks = [
      widget.service.checkBridge,
      widget.service.checkStorage,
      widget.service.checkVault,
      () => checkPublicService(widget.mirror),
    ];
    for (var i = 0; i < checks.length; i++) {
      if (!mounted) return;
      if (i == 3 && (!network || widget.mirror.isDemo)) {
        setState(() => states[i] = _CheckStatus.skipped);
        continue;
      }
      setState(() => states[i] = _CheckStatus.running);
      var passed = false;
      try {
        passed = await checks[i]();
      } catch (_) {
        passed = false;
      }
      if (!mounted) return;
      setState(
        () => states[i] = passed ? _CheckStatus.passed : _CheckStatus.failed,
      );
    }
    if (mounted) {
      setState(() {
        busy = false;
        finishedAt = DateTime.now();
      });
    }
  }

  @override
  Widget build(BuildContext context) => MaintenanceScaffold(
    title: '运行自检',
    children: [
      AppleSection(
        header: const Text('检查应用运行环境'),
        footer: const Text(
          '检查只在你点击后运行。不登录学校账号、不提交业务操作、不上传诊断报告。公开服务连通不代表所有学校接口均可用。',
        ),
        children: [
          AppleListTile(
            title: Text(busy ? '正在检查…' : '开始本机自检'),
            subtitle: const Text('检查组件、文件读写和安全存储'),
            leading: const Icon(
              CupertinoIcons.checkmark_shield,
              color: AppleDesign.accent,
            ),
            trailing: busy
                ? const CupertinoActivityIndicator()
                : const CupertinoListTileChevron(),
            onTap: busy ? null : () => run(),
          ),
          AppleListTile(
            title: const Text('包含公开网络检查'),
            subtitle: Text(
              widget.mirror.isDemo ? '离线演示不进行网络检查' : '额外访问图书馆官网，不需要登录',
            ),
            trailing: const CupertinoListTileChevron(),
            onTap: busy || widget.mirror.isDemo
                ? null
                : () => run(network: true),
          ),
        ],
      ),
      AppleSection(
        header: const Text('检查项目'),
        footer: finishedAt == null
            ? null
            : Text('完成于 ${_time(finishedAt!)}。失败项目可重新检查；安全存储失败可能影响记住密码。'),
        children: [
          for (var i = 0; i < states.length; i++)
            AppleListTile(
              title: Text(titles[i]),
              subtitle: Text(
                '${details[i]}\n${switch (states[i]) {
                  _CheckStatus.waiting => '未检查',
                  _CheckStatus.running => '检查中…',
                  _CheckStatus.passed => '通过',
                  _CheckStatus.failed => '未通过，请重试或检查系统设置',
                  _CheckStatus.skipped => '未执行网络检查',
                }}',
              ),
              leading: states[i] == _CheckStatus.running
                  ? const CupertinoActivityIndicator()
                  : Icon(
                      switch (states[i]) {
                        _CheckStatus.passed =>
                          CupertinoIcons.checkmark_circle_fill,
                        _CheckStatus.failed =>
                          CupertinoIcons.exclamationmark_circle,
                        _ => CupertinoIcons.circle,
                      },
                      color: switch (states[i]) {
                        _CheckStatus.passed => CupertinoColors.systemGreen,
                        _CheckStatus.failed => CupertinoColors.systemOrange,
                        _ => CupertinoColors.secondaryLabel.resolveFrom(
                          context,
                        ),
                      },
                    ),
            ),
        ],
      ),
    ],
  );
}
