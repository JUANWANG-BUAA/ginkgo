import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/mirror_service.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';

import 'cgyy_gateway.dart';
import 'cgyy_models.dart';
import 'cgyy_widgets.dart';

class CgyyLockCodePage extends StatefulWidget {
  const CgyyLockCodePage({
    super.key,
    this.demo = false,
    this.loader,
    this.service,
  });

  final bool demo;
  final CgyyLoader? loader;
  final CampusGateway? service;

  @override
  State<CgyyLockCodePage> createState() => _CgyyLockCodePageState();
}

class _CgyyLockCodePageState extends State<CgyyLockCodePage> {
  CgyyLockCode? code;
  String? error;
  bool busy = false;
  int request = 0;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({bool force = false}) async {
    final serial = ++request;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await cgyyLockCode(
        demo: widget.demo,
        loader: widget.loader,
        service: widget.service,
        forceRefresh: force,
      );
      if (!mounted || serial != request) return;
      setState(() {
        busy = false;
        if (result.failure != null) {
          error = failureMessage(result.failure);
          code = null;
        }
        if (result.payload != null) code = cgyyLockCodeData(result.payload!);
      });
    } catch (_) {
      if (mounted && serial == request) {
        setState(() {
          busy = false;
          error = failureMessage(null);
          code = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
      context,
    ),
    navigationBar: CupertinoNavigationBar(
      middle: const Text('门锁密码'),
      previousPageTitle: '研讨室',
      trailing: AppleGlassButton(
        label: '刷新门锁密码',
        onPressed: busy ? null : () => load(force: true),
        child: const Icon(CupertinoIcons.refresh),
      ),
    ),
    child: SafeArea(
      child: ListView(
        children: [
          if (busy) const GinkgoLoadingView(label: '正在读取门锁密码…'),
          if (error != null)
            const CgyyStatusSection(
              title: '门锁密码读取失败',
              description: '请检查学校会话和网络后重试；读取失败不代表没有预约。',
              isError: true,
            ),
          if (error != null)
            AppleSection(
              children: [
                CupertinoButton(
                  minimumSize: const Size(48, 48),
                  onPressed: busy ? null : () => load(force: true),
                  child: const Text('重试'),
                ),
              ],
            ),
          if (code case final current?) ...[
            if (current.hasPassword)
              AppleSection(
                header: const Text('当前时段可开门'),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: Text(
                        current.qrCode!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 4,
                        ),
                      ),
                    ),
                  ),
                  if (current.dueDate != null)
                    AppleListTile(
                      title: const Text('有效期至'),
                      subtitle: Text(current.dueDate!),
                    ),
                ],
              )
            else
              CgyyStatusSection(
                title: current.hasUpcomingReservation ? '未到开门时段' : '当前无可用预约',
                description: current.hasUpcomingReservation
                    ? '门锁密码会在可开门时段内返回，可稍后手动刷新。'
                    : '当前没有可用于获取门锁密码的预约记录。',
              ),
            if (current.hasUpcomingReservation)
              AppleSection(
                header: const Text('预约信息'),
                children: [
                  if (current.tradeNo != null)
                    AppleListTile(
                      title: const Text('预约单号'),
                      subtitle: Text(current.tradeNo!),
                    ),
                  if (current.location.isNotEmpty)
                    AppleListTile(
                      title: const Text('场地'),
                      subtitle: Text(current.location),
                    ),
                  if (current.orderName != null)
                    AppleListTile(
                      title: const Text('预约人'),
                      subtitle: Text(current.orderName!),
                    ),
                  if (current.reservationDate != null)
                    AppleListTile(
                      title: const Text('预约日期'),
                      subtitle: Text(current.reservationDate!),
                    ),
                  if (current.reservationDateDetail != null)
                    AppleListTile(
                      title: const Text('时段'),
                      subtitle: Text(current.reservationDateDetail!),
                    ),
                  if (current.reservationStartDate != null)
                    AppleListTile(
                      title: const Text('开始时间'),
                      subtitle: Text(current.reservationStartDate!),
                    ),
                  if (current.reservationEndDate != null)
                    AppleListTile(
                      title: const Text('结束时间'),
                      subtitle: Text(current.reservationEndDate!),
                    ),
                ],
              ),
          ],
        ],
      ),
    ),
  );
}
