import '../application/graduate_credit_map.dart';

/// Synthetic presentation fixture. Values are explicit, never calculated from
/// a course pool and never presented as a real user's school execution report.
mixin DemoGraduateCreditMap implements GraduateCreditMapGateway {
  @override
  Future<GraduateCreditMapRead> graduateCreditMap({
    bool forceRefresh = false,
  }) async => GraduateCreditMapRead(
    data: GraduateCreditMap(
      notice: '演示数据：合成执行报告，不代表学校要求或真实个人学分。',
      summary: GraduateCreditNode(
        sourceIndex: 0,
        title: '培养方案执行报告',
        progress: const GraduateCreditMetrics(
          state: GraduateCreditState.incomplete,
          requiredCredits: 32,
          earned: 8,
          pending: null,
          remaining: 24,
          ratio: 0.25,
        ),
      ),
      nodes: [
        GraduateCreditNode(
          sourceIndex: 1,
          title: '合成类别',
          progress: const GraduateCreditMetrics(
            state: GraduateCreditState.incomplete,
            requiredCredits: 6,
            earned: 2,
            pending: 2,
            remaining: 4,
            ratio: 1 / 3,
          ),
          rows: const [
            GraduateCreditRow(
              title: '合成课程',
              detail: '学校完成状态待确认（演示）',
              isCourse: true,
              credit: 2,
            ),
          ],
        ),
        GraduateCreditNode(
          sourceIndex: 2,
          title: '合成类别 · 课组',
          progress: const GraduateCreditMetrics(
            state: GraduateCreditState.unknown,
            requiredCredits: 3,
          ),
        ),
      ],
    ),
  );
}
