import 'package:flutter/cupertino.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_preferences.dart';
import 'accent_theme_preview.dart';
import 'apple_design.dart';
import 'apple_widgets.dart';
import 'maintenance_pages.dart';
import 'system_settings_service.dart';
import 'reminders.dart';

class AppearancePage extends StatelessWidget {
  const AppearancePage({super.key});
  @override
  Widget build(BuildContext context) {
    final preferences = AppPreferencesScope.of(context);
    return MaintenanceScaffold(
      title: '显示与阅读',
      children: [
        AppleSection(
          header: const Text('外观'),
          footer: const Text('跟随系统会随手机的深浅色设置自动切换。'),
          children: [
            for (final item in AppAppearance.values)
              AppleListTile(
                key: ValueKey('appearance-${item.name}'),
                leading: Icon(switch (item) {
                  AppAppearance.system => CupertinoIcons.circle_lefthalf_fill,
                  AppAppearance.light => CupertinoIcons.sun_max,
                  AppAppearance.dark => CupertinoIcons.moon,
                }),
                title: Text(item.label),
                trailing: preferences.appearance == item
                    ? Icon(
                        CupertinoIcons.check_mark,
                        color: CupertinoTheme.of(context).primaryColor,
                      )
                    : null,
                onTap: () => preferences.update(appearance: item),
              ),
          ],
        ),
        const AppleSection(
          header: Text('强调色'),
          footer: Text('点选即刻应用，深浅色自动搭配。仅更改本机显示，不改变警告和错误等状态色。'),
          children: [AccentThemePicker()],
        ),
        AppleSection(
          header: const Text('阅读与动效'),
          children: [
            ApplePickerTile<double>(
              title: '文字大小',
              value: preferences.textSize,
              values: const [1, 1.15, 1.3],
              label: (value) => switch (value) {
                1 => '跟随系统',
                1.15 => '较大（系统字号 × 1.15）',
                _ => '更大（系统字号 × 1.3）',
              },
              onSelected: (item) => preferences.update(textSize: item),
            ),
            AppleListTile(
              title: const Text('紧凑列表'),
              subtitle: const Text('减少列表行间距，保留完整文字和点按区域'),
              trailing: CupertinoSwitch(
                value: preferences.compactLists,
                onChanged: (value) => preferences.update(compactLists: value),
              ),
            ),
            AppleListTile(
              title: const Text('减少动态效果'),
              subtitle: const Text('系统已开启时始终生效'),
              trailing: CupertinoSwitch(
                value: preferences.reduceMotion,
                onChanged: (value) => preferences.update(reduceMotion: value),
              ),
            ),
          ],
        ),
        if (preferences.saveError != null)
          AppleSection(
            children: [AppleListTile(title: Text(preferences.saveError!))],
          ),
      ],
    );
  }
}

class SystemPreferencesPage extends StatefulWidget {
  const SystemPreferencesPage({
    super.key,
    this.service = const NativeSystemSettingsService(),
  });
  final SystemSettingsService service;
  @override
  State<SystemPreferencesPage> createState() => _SystemPreferencesPageState();
}

class _SystemPreferencesPageState extends State<SystemPreferencesPage>
    with WidgetsBindingObserver {
  String permission = 'loading';
  String? notice;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh();
  }

  Future<void> refresh() async {
    try {
      final value = await widget.service.notificationPermission();
      if (mounted) setState(() => permission = value);
    } catch (_) {
      if (mounted) setState(() => permission = 'unknown');
    }
  }

  Future<void> request() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final value = await widget.service.requestNotifications();
      if (mounted) {
        setState(() => permission = value);
        await ReminderScope.of(context)?.reschedule();
      }
    } catch (_) {
      if (mounted) setState(() => notice = '未能请求通知权限，请到系统设置查看');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> open(Future<bool> Function() action) async {
    try {
      if (await action()) return;
    } catch (_) {
      // Present a fixed message, never a platform exception or device data.
    }
    if (mounted) setState(() => notice = '未能打开系统设置，请从系统的应用信息页进入');
  }

  @override
  Widget build(BuildContext context) => MaintenanceScaffold(
    title: '通知与后台',
    children: [
      AppleSection(
        header: const Text('通知'),
        footer: const Text(
          '签到每节课提醒一次；未完成作业在截止前 48 小时和 24 小时提醒。系统通知隐藏课程和作业名称。Android 使用非精确定时，省电和休眠可能延迟；重启设备后请打开应用重排。其他平台暂仅提供应用内提示。',
        ),
        children: [
          AppleListTile(
            title: const Text('系统通知权限'),
            subtitle: Text(switch (permission) {
              'loading' => '读取中…',
              'granted' => '已允许',
              'notRequested' => '尚未请求',
              'denied' => '未允许，请到系统设置开启',
              'unsupported' => '请在系统通知设置中查看',
              _ => '暂时无法读取',
            }),
          ),
          if (widget.service.isAndroid && permission == 'notRequested')
            AppleListTile(
              title: const Text('请求通知权限'),
              onTap: busy ? null : request,
              trailing: busy
                  ? const CupertinoActivityIndicator()
                  : const CupertinoListTileChevron(),
            ),
          AppleListTile(
            title: const Text('打开系统通知设置'),
            trailing: const CupertinoListTileChevron(),
            onTap: () => open(widget.service.openNotifications),
          ),
        ],
      ),
      if (ReminderScope.of(context) case final ReminderController reminders)
        AppleSection(
          header: const Text('提醒规则'),
          footer: Text(
            reminders.hint ??
                '基于最近成功读取的数据，前台每两分钟刷新；不会自动签到或提交作业。本地计划 ${reminders.scheduled} 条，不代表系统实际投递数量。',
          ),
          children: [
            AppleListTile(
              title: const Text('课前签到提醒'),
              subtitle: const Text('课前 10 分钟 · 每节课一次'),
              trailing: CupertinoSwitch(
                value: reminders.checkinEnabled,
                onChanged: (value) => reminders.setEnabled('checkin', value),
              ),
            ),
            AppleListTile(
              title: const Text('作业截止提醒'),
              subtitle: const Text('提前两天和一天 · 仅个人课程未完成作业'),
              trailing: CupertinoSwitch(
                value: reminders.homeworkEnabled,
                onChanged: (value) => reminders.setEnabled('homework', value),
              ),
            ),
          ],
        ),
      AppleSection(
        header: const Text('启动与后台运行'),
        footer: Text(
          widget.service.isAndroid
              ? 'Android 的自启动和电池管理因手机品牌而异，请在应用信息中的“电池”或“自启动”查看。Ginkgo 目前不会开机自动启动，也不会常驻后台。'
              : '启动权限由系统管理；Windows 登录启动尚未注册。',
        ),
        children: [
          AppleListTile(
            title: Text(widget.service.isAndroid ? '打开应用系统设置' : '打开系统启动设置'),
            subtitle: const Text('查看此设备可用的系统选项'),
            trailing: const CupertinoListTileChevron(),
            onTap: () => open(widget.service.openAppSettings),
          ),
        ],
      ),
      if (notice != null)
        AppleSection(children: [AppleListTile(title: Text(notice!))]),
    ],
  );
}

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});
  @override
  Widget build(BuildContext context) => const MaintenanceScaffold(
    title: '账号与隐私',
    children: [
      AppleSection(
        header: Text('账号与自动登录'),
        children: [
          AppleListTile(
            title: Text('记住密码'),
            subtitle: Text('由登录页的“记住密码”选项控制。凭据保存在系统安全存储中，退出登录会删除。'),
          ),
          AppleListTile(
            title: Text('学校会话'),
            subtitle: Text('Cookie 和各业务系统的短期令牌只保存在本机内存。会话失效时可能需要重新登录或验证码。'),
          ),
        ],
      ),
      AppleSection(
        header: Text('数据去向'),
        children: [
          AppleListTile(
            title: Text('校园服务直连'),
            subtitle: Text('请求直接发往北航系统，或通过学校官方 WebVPN 网关；学校账号与密码不发送给项目作者。'),
          ),
          AppleListTile(
            title: Text('本机数据'),
            subtitle: Text('查询快照按账号隔离，个人待办保存在本机。可在设置中清除查询快照，个人待办会保留。'),
          ),
          AppleListTile(
            title: Text('软件更新'),
            subtitle: Text('检查和下载安装包会连接 GitHub。更新请求与学校会话隔离，不携带学校 Cookie 或密码。'),
          ),
          AppleListTile(
            title: Text('诊断与反馈'),
            subtitle: Text('自检结果在本机显示。反馈前请遮盖姓名、学号、课表和票据，不要发送密码或原始网络记录。'),
          ),
        ],
      ),
    ],
  );
}

class AboutPage extends StatefulWidget {
  const AboutPage({
    super.key,
    this.system = const NativeSystemSettingsService(),
  });
  final SystemSettingsService system;
  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  String? notice;
  Future<void> link(String url) async {
    try {
      if (await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      )) {
        return;
      }
    } catch (_) {}
    if (mounted) setState(() => notice = '无法打开链接，请稍后重试');
  }

  Future<void> share() async {
    try {
      final shared = await widget.system.shareProject();
      if (mounted) {
        setState(
          () => notice = shared
              ? widget.system.isAndroid
                    ? '已打开系统分享'
                    : '项目主页已复制'
              : '未能打开分享，请稍后重试',
        );
      }
    } catch (_) {
      if (mounted) setState(() => notice = '未能打开分享，请稍后重试');
    }
  }

  @override
  Widget build(BuildContext context) => MaintenanceScaffold(
    title: '关于与致谢',
    children: [
      const AppleSection(
        children: [
          AppleListTile(
            leading: Icon(
              CupertinoIcons.leaf_arrow_circlepath,
              color: AppleDesign.accent,
              size: 30,
            ),
            title: Text('Ginkgo · 北航校园工作台'),
            subtitle: Text('校园日常，从容有序。\n以 MIT License 开源。'),
          ),
        ],
      ),
      AppleSection(
        header: const Text('项目与分享'),
        footer: const Text('如果 Ginkgo 帮到了你，欢迎分享项目主页，或在 GitHub 点一个 Star。'),
        children: [
          AppleListTile(
            title: const Text('项目主页'),
            trailing: const CupertinoListTileChevron(),
            onTap: () => link('https://juanwang-buaa.github.io/ginkgo/'),
          ),
          AppleListTile(
            title: const Text('GitHub 仓库与反馈'),
            trailing: const CupertinoListTileChevron(),
            onTap: () => link('https://github.com/JUANWANG-BUAA/ginkgo'),
          ),
          AppleListTile(
            title: const Text('分享 Ginkgo'),
            leading: const Icon(CupertinoIcons.share),
            onTap: share,
          ),
        ],
      ),
      AppleSection(
        header: const Text('致谢 UBAA'),
        footer: const Text(
          '课表、成绩与校园服务的协议研究和实现参考了同以 MIT 许可发布的 UBAA（BUAASubnet/UBAA），谨致谢意。Ginkgo 是独立的第三方校园客户端。',
        ),
        children: [
          AppleListTile(
            title: const Text('访问 UBAA 开源项目'),
            subtitle: const Text('BUAASubnet / UBAA'),
            trailing: const CupertinoListTileChevron(),
            onTap: () => link('https://github.com/BUAASubnet/UBAA'),
          ),
        ],
      ),
      if (notice != null)
        AppleSection(children: [AppleListTile(title: Text(notice!))]),
    ],
  );
}
