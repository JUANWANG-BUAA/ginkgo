import SwiftUI

struct GradeView: View {
  @EnvironmentObject private var appState: AppState
  @EnvironmentObject private var model: GradeViewModel
  @AppStorage("compactLists") private var compactLists = false
  @State private var search = ""

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        AcademicPageHeader(
          section: "教务 · 学业记录",
          title: "成绩",
          subtitle: "按学期查看课程分数与学分加权统计",
          symbol: "chart.bar.xaxis"
        )

        if let snapshot = model.snapshot {
          semesterBar(snapshot)

          if let error = model.errorMessage {
            StatusNotice(message: "\(error) · 保留上次同步的成绩", kind: .warning)
          } else if let feedback = model.feedback {
            StatusNotice(message: feedback, kind: .success)
          }

          if snapshot.courses.isEmpty {
            PageEmptyState(
              symbol: model.errorMessage == nil ? "chart.bar.xaxis" : "wifi.exclamationmark",
              title: model.errorMessage == nil ? "该学期暂无已发布成绩" : "暂时无法确认成绩",
              detail: model.errorMessage == nil ? "成绩发布后可在这里刷新查看。" : "这次刷新没有返回可用数据，请重试后再判断是否暂无成绩。"
            )
          } else {
            statistics(snapshot)
            statisticsMethod
            courseResults(snapshot)
          }
        } else if model.isLoading {
          VStack(spacing: 12) {
            ProgressView()
            Text("正在查询成绩服务…").foregroundStyle(.secondary)
          }
          .frame(maxWidth: .infinity, minHeight: 260)
        } else {
          PageEmptyState(symbol: "wifi.exclamationmark", title: "暂时无法获取成绩", detail: model.errorMessage ?? "请检查网络连接后重试。")
          Button("重试") { Task { await model.refresh() } }
            .buttonStyle(.borderedProminent)
        }
      }
      .ginkgoPagePadding()
      .frame(maxWidth: 940, alignment: .leading)
      .frame(maxWidth: .infinity)
    }
    .background(Color.ginkgoWindowBackground)
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button { Task { await model.refresh() } } label: {
          Label("刷新成绩", systemImage: "arrow.clockwise")
        }
        .disabled(model.isLoading)
        .help("刷新成绩")
        .keyboardShortcut("r", modifiers: .command)
      }
    }
    .task(id: appState.user?.schoolid) {
      if let account = appState.user?.schoolid { await model.start(account: account) }
    }
    .onChange(of: model.feedback) { _, message in
      if let message { appState.showToast(message) }
    }
    .onChange(of: model.needsSessionCheck) { _, needed in
      if needed { Task { _ = try? await appState.confirmSessionAfterAuthFailure() } }
    }
  }

  private func semesterBar(_ snapshot: GradeSnapshot) -> some View {
    HStack(spacing: 14) {
      Picker("学期", selection: Binding(get: { snapshot.term.id }, set: { id in
        if let term = model.terms.first(where: { $0.id == id }) { Task { await model.refresh(term: term) } }
      })) {
        ForEach(model.terms.isEmpty ? [snapshot.term] : model.terms) { term in
          Text(term.name).tag(term.id)
        }
      }
      .frame(maxWidth: 320)

      Spacer(minLength: 8)
      if model.isLoading { ProgressView().controlSize(.small).accessibilityLabel("正在更新成绩") }
      Label("同步于 \(snapshot.fetchedAt.formatted(date: .abbreviated, time: .shortened))", systemImage: "clock")
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }
    .academicPanel(inset: 12)
  }

  private func statistics(_ snapshot: GradeSnapshot) -> some View {
    let average = snapshot.weightedAverage.map { $0.formatted(.number.precision(.fractionLength(2))) } ?? "—"
    let gpa = snapshot.gradePointAverage.map { $0.formatted(.number.precision(.fractionLength(2))) } ?? "—"
    return AcademicMetricStrip(metrics: [
      AcademicMetric(
        id: "published",
        title: "已发布课程",
        value: "\(snapshot.courses.count) 门",
        detail: "当前学期",
        symbol: "doc.text",
        tint: .primary
      ),
      AcademicMetric(
        id: "average",
        title: "加权平均分",
        value: average,
        detail: "仅计数值成绩",
        symbol: "chart.line.uptrend.xyaxis",
        tint: .accentColor,
        isProminent: true
      ),
      AcademicMetric(
        id: "gpa",
        title: "参考绩点",
        value: gpa,
        detail: "百分制算法",
        symbol: "gauge.with.dots.needle.33percent",
        tint: .primary
      )
    ])
  }

  private var statisticsMethod: some View {
    DisclosureGroup {
      Text("参考绩点按学分加权：60–100 分使用 4 − 3 × (100 − 分数)² ÷ 1600；低于 60 分按 0 计入。等级制、未发布或无有效学分的课程不参与统计，结果供参考。")
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.top, 8)
    } label: {
      Label("统计口径", systemImage: "info.circle")
        .font(.callout)
    }
    .padding(12)
    .background(Color.ginkgoSidebarBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
  }

  private func courseResults(_ snapshot: GradeSnapshot) -> some View {
    let courses = filteredCourses(snapshot)
    return VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 16) {
        VStack(alignment: .leading, spacing: 3) {
          Text("课程成绩").font(.headline)
          Text("显示 \(courses.count) / \(snapshot.courses.count) 门")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Spacer(minLength: 8)
        SearchField(prompt: "搜索课程名称或课程号", text: $search)
          .frame(maxWidth: 340)
      }

      if courses.isEmpty {
        ContentUnavailableView.search(text: search)
          .frame(maxWidth: .infinity, minHeight: 180)
          .academicPanel(inset: 0)
      } else {
        VStack(spacing: 0) {
          HStack(spacing: 16) {
            Text("课程")
              .frame(maxWidth: .infinity, alignment: .leading)
            Text("学分").frame(width: 76, alignment: .trailing)
            Text("成绩").frame(width: 76, alignment: .trailing)
          }
          .font(.caption.weight(.medium))
          .foregroundStyle(.secondary)
          .padding(.horizontal, 16)
          .padding(.vertical, 10)
          .background(Color.ginkgoSidebarBackground.opacity(0.72))

          Divider()

          ProgressiveList(items: courses, pageSize: 60, rowSpacing: 0) { course in
            VStack(spacing: 0) {
              GradeRecordRow(course: course, compact: compactLists)
                .padding(.horizontal, 16)
              Divider().padding(.leading, 16)
            }
          }
        }
        .academicPanel(inset: 0)
      }
    }
  }

  private func filteredCourses(_ snapshot: GradeSnapshot) -> [GradeCourse] {
    snapshot.courses(matching: search)
  }
}

private struct GradeRecordRow: View {
  let course: GradeCourse
  let compact: Bool

  var body: some View {
    HStack(alignment: .center, spacing: 16) {
      VStack(alignment: .leading, spacing: 4) {
        Text(course.name)
          .font(.body.weight(.medium))
          .fixedSize(horizontal: false, vertical: true)
        let context = [course.code, course.courseType].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
        if !context.isEmpty {
          Text(context)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      Text(course.credit.map { "\($0.formatted())" } ?? "—")
        .font(.callout.monospacedDigit())
        .foregroundStyle(.secondary)
        .frame(width: 76, alignment: .trailing)
        .accessibilityLabel("学分 \(course.credit.map { $0.formatted() } ?? "未确认")")

      Text(course.score)
        .font(.headline.monospacedDigit())
        .foregroundStyle(.primary)
        .frame(width: 76, alignment: .trailing)
        .accessibilityLabel("成绩 \(course.score)")
    }
    .frame(minHeight: compact ? 44 : 58)
    .padding(.vertical, compact ? 5 : 7)
    .accessibilityElement(children: .combine)
  }
}
