import 'dart:io';

import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/application/contracts.dart';
import 'package:ginkgo_mirror/infrastructure/demo_mirror_service.dart';
import 'package:ginkgo_mirror/src/rust/frb_generated.dart';

void main() {
  final library = Platform.environment['GINKGO_HOST_BRIDGE'];
  test(
    'native demo homework list and detail preserve the same assignment',
    () async {
      await RustLib.init(externalLibrary: ExternalLibrary.open(library!));
      const service = DemoMirrorService();
      final list = await service.homework();
      expect(list.items, isNotEmpty);
      expect(
        list.items.any((item) => item.status == HomeworkStatus.submitted),
        isTrue,
      );
      for (final item in list.items) {
        for (final id in [
          item.id,
          item.id.replaceFirst(RegExp('^spoc:'), ''),
        ]) {
          final detail = await service.homeworkDetail(id);
          expect(detail.status, switch (item.status) {
            HomeworkStatus.submitted => '已提交',
            HomeworkStatus.pending => '待完成',
            HomeworkStatus.unknown => '待确认',
          }, reason: item.id);
          expect(detail.publishedAt, item.publishedAt);
          expect(detail.dueAt, item.dueAt);
          expect(detail.score, item.score);
          expect(detail.stale, isFalse);
        }
      }
    },
    skip: library == null
        ? 'Requires an explicitly built local host bridge'
        : false,
  );
}
