import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/platform/android_update_controller.dart';
import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';

class UpdateDownloadSection extends StatelessWidget {
  const UpdateDownloadSection({
    super.key,
    required this.asset,
    required this.controller,
  });
  final AndroidDownload asset;
  final AndroidUpdateController controller;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final current = controller.asset?.sha256 == asset.sha256;
      final phase = current ? controller.phase : UpdateDownloadPhase.idle;
      return AppleSection(
        header: const Text('下载与安装'),
        footer: const Text(
          '下载来自 GitHub 官方服务，不携带学校账号信息。可离开此页继续下载；进程被关闭后，在此重新检查同一版本即可续传。安装会核对文件、包名和签名，并交由 Android 确认。',
        ),
        children: [
          ApplePickerTile<UpdateDownloadSource>(
            title: '下载入口',
            value: controller.source,
            values: UpdateDownloadSource.values,
            label: (item) => item.label,
            enabled: !controller.busy,
            onSelected: controller.selectSource,
          ),
          AppleListTile(
            title: Text(switch (phase) {
              UpdateDownloadPhase.idle => '下载 Android 更新',
              UpdateDownloadPhase.downloading => '正在下载…',
              UpdateDownloadPhase.paused => '继续下载',
              UpdateDownloadPhase.verifying => '正在校验安装包…',
              UpdateDownloadPhase.ready => '安装更新',
              UpdateDownloadPhase.failed => '重试下载',
            }),
            subtitle: Text(
              current
                  ? controller.sizeLabel
                  : '${(asset.size / 1048576).toStringAsFixed(1)} MB',
            ),
            leading: Icon(
              phase == UpdateDownloadPhase.ready
                  ? CupertinoIcons.checkmark_shield
                  : CupertinoIcons.arrow_down_circle,
              color: AppleDesign.accent,
            ),
            trailing: controller.busy
                ? const GinkgoActivity(size: 16)
                : const CupertinoListTileChevron(),
            onTap: controller.busy
                ? null
                : phase == UpdateDownloadPhase.ready
                ? controller.install
                : () => controller.download(asset),
          ),
          if (current && phase == UpdateDownloadPhase.downloading) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Semantics(
                label: '下载进度',
                value: '${(controller.progress * 100).round()}%',
                child: LayoutBuilder(
                  builder: (context, bounds) => ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: Stack(
                      children: [
                        Container(
                          height: 4,
                          color: CupertinoColors.quaternarySystemFill
                              .resolveFrom(context),
                        ),
                        Container(
                          height: 4,
                          width: bounds.maxWidth * controller.progress,
                          color: CupertinoTheme.of(context).primaryColor,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            AppleListTile(title: const Text('暂停下载'), onTap: controller.pause),
          ],
          if (current && controller.message != null)
            AppleListTile(title: Text(controller.message!)),
        ],
      );
    },
  );
}
