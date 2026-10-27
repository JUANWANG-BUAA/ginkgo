import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/application/failure_message.dart';
import 'package:ginkgo_mirror/application/learning.dart';
import 'package:ginkgo_mirror/application/learning_file_actions.dart';
import 'package:ginkgo_mirror/application/refresh_section.dart';
import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';

class LearningFileButton extends StatefulWidget {
  const LearningFileButton({
    super.key,
    required this.download,
    required this.saveFile,
    required this.isCurrent,
    required this.contextToken,
  });
  final Future<LearningDownload> Function() download;
  final LearningFileSaver? saveFile;
  final bool Function() isCurrent;
  final String contextToken;
  @override
  State<LearningFileButton> createState() => LearningFileButtonState();
}

class LearningFileButtonState extends State<LearningFileButton> {
  bool busy = false;
  String? message;
  LearningSavedFile? saved;
  int epoch = 0;
  bool current(int e) =>
      mounted &&
      e == epoch &&
      widget.isCurrent() &&
      (ModalRoute.of(context)?.isCurrent ?? true);
  @override
  void didUpdateWidget(covariant LearningFileButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.contextToken != widget.contextToken) {
      epoch++;
      busy = false;
      saved = null;
      message = null;
    }
  }

  Future<void> save() async {
    if (busy || !current(epoch)) return;
    final saver = widget.saveFile;
    if (saver == null) {
      setState(() => message = '当前平台保存能力不可用，请前往官网');
      return;
    }
    final e = epoch;
    setState(() {
      busy = true;
      saved = null;
      message = null;
    });
    try {
      final file = await widget.download();
      if (!current(e)) return;
      final result = await saver(file, () => current(e));
      if (current(e)) {
        setState(() {
          saved = result;
          message = result == null ? '已取消保存或上下文已改变' : '已保存';
        });
      }
    } catch (_) {
      if (current(e)) setState(() => message = '下载或保存失败，请重试或前往官网');
    } finally {
      if (current(e)) setState(() => busy = false);
    }
  }

  Future<void> open() async {
    final e = epoch, file = saved;
    if (file == null || !current(e)) return;
    try {
      await file.open();
    } catch (_) {
      if (current(e)) setState(() => message = '文件已保存，但无法打开，请从文件管理器查看');
    }
  }

  @override
  void dispose() {
    epoch++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 150,
    child: Column(
      children: [
        CupertinoButton(
          onPressed: busy ? null : save,
          child: Text(busy ? '正在下载…' : '下载并保存'),
        ),
        if (saved != null)
          CupertinoButton(onPressed: open, child: const Text('打开已保存文件')),
        if (message != null)
          Text(message!, style: const TextStyle(fontSize: 12)),
      ],
    ),
  );
}

class LearningReadStatus<T> extends StatelessWidget {
  const LearningReadStatus({
    super.key,
    required this.title,
    required this.section,
    required this.supported,
    required this.onRefresh,
  });
  final String title;
  final RefreshSection<LearningRead<T>> section;
  final bool supported;
  final VoidCallback onRefresh;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (!supported) LearningText('当前服务暂不支持$title'),
      if (supported) ...[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerRight,
            child: CupertinoButton(
              key: ValueKey('learning-refresh-$title'),
              minimumSize: const Size(48, 48),
              onPressed: section.loading ? null : onRefresh,
              child: Text('刷新$title'),
            ),
          ),
        ),
        SectionFeedback(
          loading: section.loading,
          label: '正在读取$title…',
          hasData: section.value != null,
          error: section.error,
          onRetry: onRefresh,
        ),
        if (section.value?.stale == true)
          const LearningText('旧缓存 · 可能不是最新结果', warning: true),
      ],
    ],
  );
}

class LearningText extends StatelessWidget {
  const LearningText(this.text, {super.key, this.heading = false, this.warning = false});
  final String text;
  final bool heading, warning;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    child: Text(
      text,
      style: TextStyle(
        fontSize: heading ? 22 : 16,
        height: 1.4,
        fontWeight: heading ? FontWeight.w600 : null,
        color: warning
            ? AppleDesign.statusUncertain.resolveFrom(context)
            : null,
      ),
    ),
  );
}

bool presentText(String? value) => value != null && value.trim().isNotEmpty;
Uri? httpsUri(String source) {
  final uri = Uri.tryParse(source);
  return uri != null &&
          uri.scheme == 'https' &&
          uri.host.isNotEmpty &&
          uri.userInfo.isEmpty
      ? uri
      : null;
}

Future<void> learningRefresh<T>(
  RefreshSection<LearningRead<T>> section,
  Future<LearningRead<T>> Function() read,
  bool force,
) => section.refresh(
  () async {
    final result = await read();
    return SectionResult(
      value: result,
      error: result.failure == null ? null : failureMessage(result.failure),
    );
  },
  fallbackError: '本地服务暂时不可用，请重试',
  force: force,
);
