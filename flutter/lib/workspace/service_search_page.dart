import 'package:flutter/cupertino.dart';
import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/workspace/workspace_catalog.dart';
import 'package:ginkgo_mirror/shared/school_links.dart';

enum ServiceArea {
  academic('学业'),
  books('图书与借阅'),
  spaces('空间资源'),
  campus('校园生活'),
  information('资讯与就业'),
  support('健康／网络／办事');

  const ServiceArea(this.label);
  final String label;
}

/// Metadata refers to the existing navigation destination, not a second page factory.
class ServiceDescriptor {
  const ServiceDescriptor({
    this.destination,
    this.officialId,
    this.officialTitle,
    required this.area,
    required this.aliases,
    required this.description,
    required this.sensitivity,
    required this.cachePolicy,
  });
  final WorkspaceDestination? destination;
  final String? officialId, officialTitle;
  String get id => destination?.id ?? officialId!;
  String get title => destination?.title ?? officialTitle!;
  IconData get icon => destination?.icon ?? CupertinoIcons.globe;
  final ServiceArea area;
  final List<String> aliases;
  final String description, sensitivity, cachePolicy;
  bool matches(String query) {
    final needle = query.trim().toLowerCase();
    return needle.isEmpty ||
        [
          title,
          area.label,
          description,
          ...aliases,
        ].any((value) => value.toLowerCase().contains(needle));
  }
}

/// Searches compile-time metadata; it does not request school or personal data.
List<ServiceDescriptor> get searchableServices => [
  for (final destination in workspaceDestinations)
    if (destination.id != 'today' &&
        destination.id != 'settings' &&
        destination.id != 'graduate-credit-map')
      ServiceDescriptor(
        destination: destination,
        area: switch (destination.id) {
          'library-loans' => ServiceArea.books,
          'library' ||
          'cgyy' ||
          'classroom' ||
          'reservations' => ServiceArea.spaces,
          'campus-card' || 'shuttle' || 'tasks' => ServiceArea.campus,
          'notices' ||
          'career-events' ||
          'campus-activities' => ServiceArea.information,
          _ => ServiceArea.academic,
        },
        aliases: switch (destination.id) {
          'schedule' => const ['查课表', '考试', '上课'],
          'homework' => const ['作业', '截止'],
          'library' => const ['查书', '书目', '馆藏', '座位', '选座'],
          'library-loans' => const ['借书', '借阅', '还书'],
          'shuttle' => const ['校车', '班车', '摆渡车'],
          'classroom' => const ['空教室', '自习'],
          'cgyy' => const ['研讨室', '场馆'],
          'campus-card' => const ['校园卡', '余额'],
          'notices' => const ['通知', '公告'],
          'career-events' => const ['就业', '宣讲', '双选会', '招聘'],
          'campus-activities' => const ['讲座', '学术', '演出', '学术文化'],
          'checkin' => const ['签到', '打卡'],
          'tasks' => const ['本机待办', '提醒'],
          _ => const [],
        },
        description: switch (destination.id) {
          'library' => '图书馆座位及公开书目入口',
          'library-loans' => '按需读取本人借阅',
          'shuttle' => '学校公布的计划时刻',
          'campus-card' => '按需查看校园卡余额',
          'campus-activities' => '学校官网讲座与演出，含活动时间和地点',
          _ => '打开${destination.title}',
        },
        sensitivity: switch (destination.id) {
          'campus-card' || 'library-loans' || 'grades' => '个人敏感信息',
          'notices' ||
          'shuttle' ||
          'career-events' ||
          'campus-activities' => '公开信息',
          _ => '按功能权限读取',
        },
        cachePolicy:
            destination.id == 'campus-card' || destination.id == 'library-loans'
            ? '按需读取'
            : '遵循该功能的缓存策略',
      ),
  const ServiceDescriptor(
    officialId: 'official-print-guide',
    officialTitle: '自助打印使用指南',
    area: ServiceArea.academic,
    aliases: ['打印', '自助打印'],
    description: '智慧北航官方使用指南',
    sensitivity: '公开信息',
    cachePolicy: '前往官网',
  ),
  const ServiceDescriptor(
    officialId: 'official-housing-guide',
    officialTitle: '学生公寓办理流程',
    area: ServiceArea.campus,
    aliases: ['宿舍', '住宿', '入住', '退宿'],
    description: '学生中心公寓业务指南',
    sensitivity: '公开信息',
    cachePolicy: '前往官网',
  ),
  const ServiceDescriptor(
    officialId: 'official-lectures',
    officialTitle: '学术文化活动',
    area: ServiceArea.information,
    aliases: ['讲座', '学术', '演出'],
    description: '学校官网学术文化栏目',
    sensitivity: '公开信息',
    cachePolicy: '前往官网',
  ),
  const ServiceDescriptor(
    officialId: 'official-network-guide',
    officialTitle: '网络服务指南',
    area: ServiceArea.support,
    aliases: ['网络', '报修', '校园网'],
    description: '网络信息中心服务指南',
    sensitivity: '公开信息',
    cachePolicy: '前往官网',
  ),
];

class ServiceSearchPage extends StatefulWidget {
  const ServiceSearchPage({super.key, required this.context});
  final WorkspaceContext context;
  @override
  State<ServiceSearchPage> createState() => _ServiceSearchPageState();
}

class _ServiceSearchPageState extends State<ServiceSearchPage> {
  final controller = TextEditingController();
  Future<void> open(ServiceDescriptor entry) async {
    final destination = entry.destination;
    if (destination != null) {
      await Navigator.of(context).push(
        CupertinoPageRoute<void>(
          builder: (_) => destination.build(widget.context),
        ),
      );
      return;
    }
    final links = widget.context.capabilities.studentServiceLinks;
    var opened = false;
    try {
      final value = links?.studentServiceUrl(entry.id);
      opened = await openSchoolLink(value ?? '');
    } catch (_) {
      opened = false;
    }
    if (!opened && mounted) await showSchoolLinkError(context);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final matches = searchableServices
        .where((entry) => entry.matches(controller.text))
        .toList();
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('全部服务')),
      child: SafeArea(
        child: ListView(
          children: [
            Padding(
              padding: GinkgoSpacing.edgeInsetsCard,
              child: CupertinoSearchTextField(
                key: const Key('service-search'),
                controller: controller,
                placeholder: '搜索服务名称或别名',
                onChanged: (_) => setState(() {}),
              ),
            ),
            const Padding(
              padding: GinkgoSpacing.edgeInsetsPage,
              child: Text('搜索服务，不检索个人记录；未收录的服务不会出现在结果中。'),
            ),
            if (matches.isEmpty)
              const AppleSection(
                children: [
                  AppleEmptyState(
                    title: '没有找到服务',
                    description: '试试其他名称或查看学校官网。',
                  ),
                ],
              ),
            for (final area in ServiceArea.values)
              if (matches.any((entry) => entry.area == area))
                AppleSection(
                  header: Text(area.label),
                  children: [
                    for (final entry in matches.where(
                      (entry) => entry.area == area,
                    ))
                      AppleListTile(
                        key: Key('service-result-${entry.id}'),
                        leading: Icon(entry.icon),
                        title: Text(entry.title),
                        subtitle: Text(
                          '${entry.description}${entry.destination == null
                              ? widget.context.capabilities.studentServiceLinks !=
                                    null
                                    ? ' · 前往官网 ↗'
                                    : ' · 暂未接入'
                              : ''}',
                        ),
                        trailing:
                            entry.destination == null &&
                                widget.context.capabilities.studentServiceLinks ==
                                    null
                            ? null
                            : const Icon(CupertinoIcons.chevron_right),
                        onTap:
                            entry.destination == null &&
                                widget.context.capabilities.studentServiceLinks ==
                                    null
                            ? null
                            : () => open(entry),
                      ),
                  ],
                ),
          ],
        ),
      ),
    );
  }
}
