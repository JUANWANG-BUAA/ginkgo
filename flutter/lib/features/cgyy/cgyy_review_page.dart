import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/features/cgyy/cgyy_models.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/mirror_service.dart';

/// A fresh, visible review snapshot, not a background read-and-unlock action.
class CgyyReviewPage extends StatefulWidget {
  const CgyyReviewPage({super.key, required this.gateway});
  final CgyyBookingGateway gateway;
  @override
  State<CgyyReviewPage> createState() => _CgyyReviewPageState();
}

class _CgyyReviewPageState extends State<CgyyReviewPage> {
  List<CgyyOrder>? orders;
  String? reviewId;
  String? error;
  bool loading = false;
  bool acknowledging = false;
  bool checked = false;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  CgyyActionResult decode(ReadOnlyResponse response) {
    if (response.failure != null ||
        response.stale ||
        response.payload == null) {
      throw const FormatException('Review must be fresh');
    }
    return cgyyActionResult(response.payload!);
  }

  Future<void> refresh() async {
    if (loading || acknowledging) return;
    setState(() {
      loading = true;
      checked = false;
      reviewId = null;
      orders = null;
      error = null;
    });
    try {
      final result = decode(
        await widget.gateway.executeCgyy({'action': 'review'}),
      );
      final snapshot = result.review;
      if (!result.isReviewRequired || snapshot == null || snapshot.id.isEmpty) {
        throw const FormatException('Missing review identity');
      }
      if (mounted) {
        setState(() {
          reviewId = snapshot.id;
          orders = snapshot.orders;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = '未能取得最新预约记录，写入保护未解除。请重试核对，不要再次提交预约或取消。');
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> acknowledge() async {
    if (acknowledging || loading || !checked || reviewId == null) return;
    final id = reviewId!;
    setState(() => acknowledging = true);
    try {
      final confirmed = await showCupertinoDialog<bool>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('已确认上次操作结果？'),
          content: const Text(
            '这里只解除本机写入保护，不会预约或取消。记录仅覆盖有界分页读到的最近最多 20 条；若未找到目标，请先到学校预约页面核实，不能把列表为空当作未提交。解除后也不会自动重发。',
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () {
                if (ModalRoute.of(context)?.isCurrent ?? false) {
                  Navigator.pop(context, false);
                }
              },
              child: const Text('继续核对'),
            ),
            CupertinoDialogAction(
              key: const Key('cgyy-review-confirm'),
              onPressed: () {
                if (ModalRoute.of(context)?.isCurrent ?? false) {
                  Navigator.pop(context, true);
                }
              },
              child: const Text('确认解除'),
            ),
          ],
        ),
      );
      if (!mounted || confirmed != true) return;
      final result = decode(
        await widget.gateway.executeCgyy({
          'action': 'acknowledge',
          'review_id': id,
        }),
      );
      if (result.isReady) {
        if (mounted) Navigator.of(context).pop(true);
        return;
      }
      throw const FormatException('Review not acknowledged');
    } catch (_) {
      if (mounted) {
        setState(() {
          checked = false;
          reviewId = null;
          error = '核对凭据已失效或操作未完成，保护仍在。请重新读取记录后核实。';
        });
      }
    } finally {
      if (mounted) setState(() => acknowledging = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !acknowledging,
    child: CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
        context,
      ),
      child: SafeArea(
        top: false,
        child: CustomScrollView(
          key: const Key('cgyy-review-scroll'),
          slivers: [
            ApplePageHeader(
              largeTitle: const Text('核对上次操作'),
              section: '空间资源',
              subtitle: '选择场馆并查看可预约空间',
              icon: CupertinoIcons.person_3,
              border: null,
            ),
            SliverList.list(
              children: [
                const AppleSection(
                  header: Text('本次强制回查'),
                  footer: Text(
                    '只显示分页读到的最近最多 20 条，非完整历史。记录出现不等于审批通过。未找到目标或状态不明时，请保留保护并到学校页面核实。',
                  ),
                  children: [
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        '请查看下方本次重新读取的订单、地点、时段及审批状态，再决定是否解除保护。离开本页不会解除保护。',
                      ),
                    ),
                  ],
                ),
                if (loading) const GinkgoLoadingView(label: '正在核对订单…'),
                if (error != null)
                  AppleSection(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(error!),
                      ),
                    ],
                  ),
                if (orders != null)
                  AppleSection(
                    header: const Text('最新预约记录'),
                    children: [
                      if (orders!.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('本次未查到最近预约记录；这不证明上次操作未生效。'),
                        ),
                      for (final order in orders!)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(order.summary),
                        ),
                    ],
                  ),
                AppleSection(
                  children: [
                    CupertinoButton(
                      key: const Key('cgyy-review-refresh'),
                      minimumSize: const Size(48, 48),
                      onPressed: loading || acknowledging ? null : refresh,
                      child: const Text('重新读取最新记录'),
                    ),
                    if (orders != null)
                      AppleListTile(
                        title: const Text('我已看到最新记录并确认上次操作结果'),
                        subtitle: const Text('若目标不在最近记录中，已在学校页面另行核实。'),
                        trailing: CupertinoSwitch(
                          key: const Key('cgyy-review-checked'),
                          value: checked,
                          onChanged:
                              loading || acknowledging || reviewId == null
                              ? null
                              : (value) => setState(() => checked = value),
                        ),
                      ),
                    CupertinoButton(
                      key: const Key('cgyy-review-acknowledge'),
                      minimumSize: const Size(48, 48),
                      onPressed:
                          loading ||
                              acknowledging ||
                              !checked ||
                              reviewId == null
                          ? null
                          : acknowledge,
                      child: const Text('解除本机写入保护'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
