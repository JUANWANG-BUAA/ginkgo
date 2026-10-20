import 'package:flutter/cupertino.dart';

import 'coming_soon_page.dart';
import 'mirror_service.dart';

class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key, required this.service});
  final MirrorService service;
  @override
  Widget build(BuildContext context) => const ComingSoonPage(
    title: '图书馆',
    description: '图书馆座位预约需要 booking.lib 的独立 CAS 会话、场馆/区域/时段与座位只读数据；当前镜像尚未迁移。',
    symbol: CupertinoIcons.book,
    details: [
      '预约端 SSO 会话与场馆/区域/时段读取',
      '座位空闲状态与当前预约',
      '预约、签到、暂离、离馆的二次确认与回查',
      '写操作未知结果不重试',
    ],
  );
}
