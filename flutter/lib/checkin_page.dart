import 'package:flutter/cupertino.dart';

import 'coming_soon_page.dart';
import 'mirror_service.dart';

class CheckInPage extends StatelessWidget {
  const CheckInPage({super.key, required this.service});
  final MirrorService service;
  @override
  Widget build(BuildContext context) => const ComingSoonPage(
    title: '课程签到',
    description: 'iclass 课程签到需要独立的 SSO 会话、当天课程列表与逐课程确认；当前镜像尚未迁移。',
    symbol: CupertinoIcons.checkmark_seal,
    details: [
      'iclass SSO 会话与当天课程只读状态',
      '未签到 / 已签到 / 待确认状态与回查',
      '逐课程二次确认，未知结果不自动重发',
      '写操作真实往返验收后再开放',
    ],
  );
}
