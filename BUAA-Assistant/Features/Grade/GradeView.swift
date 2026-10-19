import SwiftUI

struct GradeView: View {
  @EnvironmentObject private var appState: AppState
  @EnvironmentObject private var model: GradeViewModel
  @AppStorage("compactLists") private var compactLists = false
  @State private var search = ""

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        PageHeading(eyebrow: "ACADEMIC / RESULTS", title: "成绩", subtitle: "查看已发布成绩与学期统计")
        if let snapshot = model.snapshot {
          HStack {
            Picker("学期", selection: Binding(get: { snapshot.term.id }, set: { id in
              if let term = model.terms.first(where: { $0.id == id }) { Task { await model.refresh(term: term) } }
            })) {
              ForEach(model.terms.isEmpty ? [snapshot.term] : model.terms) { term in
                Text(term.name).tag(term.id)
              }
            }
            .frame(maxWidth: 320)
            Spacer()
            if model.isLoading { ProgressView().controlSize(.small) }
          }
          if let error = model.errorMessage {
            StatusNotice(message: "\(error) · 保留上次同步的成绩", kind: .warning)
          } else if let feedback = model.feedback {
            StatusNotice(message: feedback, kind: .success)
          }
          Text("上次同步：\(snapshot.fetchedAt.formatted(date: .abbreviated, time: .shortened))")
            .font(.caption).foregroundStyle(.secondary)
          SearchField(prompt: "搜索课程名称或课程号", text: $search)
          if snapshot.courses.isEmpty {
            PageEmptyState(
              symbol: model.errorMessage == nil ? "chart.bar.xaxis" : "wifi.exclamationmark",
              title: model.errorMessage == nil ? "该学期暂无已发布成绩" : "暂时无法确认成绩",
              detail: model.errorMessage == nil ? "成绩发布后可在这里刷新查看。" : "这次刷新没有返回可用数据，请重试后再判断是否暂无成绩。"
            )
          } else if filteredCourses(snapshot).isEmpty {
            PageEmptyState(symbol: "magnifyingglass", title: "未找到匹配课程", detail: "请尝试缩短搜索词或清除筛选。")
          } else {
            statistics(snapshot)
            Text("参考绩点按学分加权：60–100 分使用 4 − 3 × (100 − 分数)² ÷ 1600；低于 60 分按 0 计入。等级制、未发布或无有效学分的课程不参与统计，结果供参考。")
              .font(.caption).foregroundStyle(.secondary)
            ProgressiveList(items: filteredCourses(snapshot), pageSize: 60) { course in
                HStack(alignment: .firstTextBaseline, spacing: 16) {
                  VStack(alignment: .leading, spacing: 4) {
                    Text(course.name).font(.body.weight(.medium))
                    Text([course.code, course.courseType].compactMap { $0 }.joined(separator: " · "))
                      .font(.caption).foregroundStyle(.secondary)
                  }
                  Spacer()
                  if let credit = course.credit {
                    Text("\(credit.formatted()) 学分").font(.callout).foregroundStyle(.secondary)
                  }
                  Text(course.score).font(.headline.monospacedDigit())
                    .frame(minWidth: 56, alignment: .trailing)
                }
                .padding(.vertical, compactLists ? 7 : 12)
                Divider()
            }
          }
        } else if model.isLoading {
          VStack(spacing: 12) {
            ProgressView()
            Text("正在查询成绩服务…").foregroundStyle(.secondary)
          }.frame(maxWidth: .infinity, minHeight: 260)
        } else {
          PageEmptyState(symbol: "wifi.exclamationmark", title: "暂时无法获取成绩", detail: model.errorMessage ?? "请检查网络连接后重试。")
          Button("重试") { Task { await model.refresh() } }.buttonStyle(.borderedProminent)
        }
      }
      .ginkgoPagePadding()
      .frame(maxWidth: 800, alignment: .leading)
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

  private func filteredCourses(_ snapshot: GradeSnapshot) -> [GradeCourse] {
    snapshot.courses(matching: search)
  }

  @ViewBuilder
  private func statistics(_ snapshot: GradeSnapshot) -> some View {
    let average = snapshot.weightedAverage.map { $0.formatted(.number.precision(.fractionLength(2))) } ?? "—"
    let gpa = snapshot.gradePointAverage.map { $0.formatted(.number.precision(.fractionLength(2))) } ?? "—"

    HStack(spacing: 12) {
      stat("已发布", value: "\(snapshot.courses.count) 门", detail: "当前学期")
      stat("加权平均分", value: average, detail: "仅计数值成绩")
      stat("参考绩点", value: gpa, detail: "百分制；不及格按 0 计入")
    }
  }

  private func stat(_ title: String, value: String, detail: String) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title).font(.caption).foregroundStyle(.secondary)
      Text(value).font(.title2.weight(.semibold)).monospacedDigit()
      Text(detail).font(.caption2).foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(16)
    .background(Color.ginkgoCardBackground, in: RoundedRectangle(cornerRadius: 12))
  }
}
