import SwiftUI

struct IOSHomeworkView: View {
  @EnvironmentObject private var appState: AppState
  @EnvironmentObject private var model: HomeworkViewModel
  @State private var search = ""
  @State private var statusFilter: HomeworkStatus?
  @State private var sourceFilter: HomeworkSource?
  private let pageSize = 40
  @State private var visibleLimit = 40

  var body: some View {
    List {
      if let snapshot = model.snapshot {
        summarySection(snapshot)

        if let error = model.errorMessage {
          Section {
            IOSInlineMessage(error, systemImage: "exclamationmark.triangle.fill", tint: .orange)
          }
        }

        let items = filteredItems(snapshot.items)
        if items.isEmpty {
          Section {
            ContentUnavailableView(
              "没有符合条件的作业",
              systemImage: "doc.text.magnifyingglass",
              description: Text(snapshot.unavailableSources.isEmpty ? "请尝试调整搜索词或筛选条件。" : "部分来源暂时不可用，当前结果可能不完整。")
            )
          }
        } else {
          Section {
            let remaining = max(0, items.count - visibleLimit)
            ForEach(items.prefix(visibleLimit)) { item in
              NavigationLink {
                IOSHomeworkDetailView(item: item)
              } label: {
                homeworkRow(item)
              }
            }
            if remaining > 0 {
              Button {
                visibleLimit += pageSize
              } label: {
                Text("显示更多（剩余 \(remaining) 项）")
              }
            }
          } header: {
            Text("作业 · \(items.count) 项")
          } footer: {
            if snapshot.unavailableSources.isEmpty == false {
              Text("未更新的来源：\(snapshot.unavailableSources.map(\.title).joined(separator: "、"))")
            }
          }
        }
      } else if model.isLoading {
        Section {
          HStack(spacing: 10) {
            ProgressView()
            Text("正在读取学校作业…")
          }
        }
      } else {
        Section {
          ContentUnavailableView(
            "作业尚未确认",
            systemImage: "doc.badge.ellipsis",
            description: Text(model.errorMessage ?? "请检查网络后重试。")
          )
          Button("重试") { Task { await model.refresh() } }
        }
      }
    }
    .listStyle(.insetGrouped)
    .navigationTitle("学校作业")
    .searchable(text: $search, prompt: "搜索作业或课程")
    .refreshable {
      visibleLimit = pageSize
      await model.refresh()
    }
    .toolbar {
      ToolbarItemGroup(placement: .topBarTrailing) {
        Menu {
          Section("状态") {
            Button {
              statusFilter = nil
            } label: {
              if statusFilter == nil {
                Label("全部状态", systemImage: "checkmark")
              } else {
                Text("全部状态")
              }
            }
            ForEach([HomeworkStatus.pending, .overdue, .submitted, .unknown], id: \.rawValue) { status in
              Button {
                statusFilter = status
              } label: {
                if statusFilter == status {
                  Label(status.title, systemImage: "checkmark")
                } else {
                  Text(status.title)
                }
              }
            }
          }
          Section("来源") {
            Button {
              sourceFilter = nil
            } label: {
              if sourceFilter == nil {
                Label("全部来源", systemImage: "checkmark")
              } else {
                Text("全部来源")
              }
            }
            ForEach(HomeworkSource.enabled) { source in
              Button {
                sourceFilter = source
              } label: {
                if sourceFilter == source {
                  Label(source.title, systemImage: "checkmark")
                } else {
                  Text(source.title)
                }
              }
            }
          }
        } label: {
          Label("筛选", systemImage: "line.3.horizontal.decrease.circle")
        }

        Button {
          Task { await model.refresh() }
        } label: {
          if model.isLoading {
            ProgressView().controlSize(.small)
          } else {
            Image(systemName: "arrow.clockwise")
          }
        }
        .disabled(model.isLoading)
        .accessibilityLabel("刷新作业")
      }
    }
    .task(id: appState.user?.schoolid) {
      guard let account = appState.user?.schoolid else { return }
      await model.start(account: account)
    }
    .onChange(of: search) { _, _ in visibleLimit = pageSize }
    .onChange(of: statusFilter) { _, _ in visibleLimit = pageSize }
    .onChange(of: sourceFilter) { _, _ in visibleLimit = pageSize }
    .onChange(of: model.needsSessionCheck) { _, needed in
      guard needed else { return }
      Task { _ = try? await appState.confirmSessionAfterAuthFailure() }
    }
  }

  private func summarySection(_ snapshot: HomeworkSnapshot) -> some View {
    let pending = snapshot.items.filter { $0.status == .pending }.count
    let overdue = snapshot.items.filter { $0.status == .overdue }.count
    let submitted = snapshot.items.filter { $0.status == .submitted }.count
    let unknown = snapshot.items.filter { $0.status == .unknown }.count
    return Section {
      Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 10) {
        GridRow {
          summaryMetric("待处理", value: pending, tint: .accentColor)
          summaryMetric("已逾期", value: overdue, tint: .orange)
        }
        GridRow {
          summaryMetric("已提交", value: submitted, tint: .green)
          summaryMetric("待确认", value: unknown, tint: .secondary)
        }
      }
      .padding(.vertical, 2)
    } header: {
      Text(snapshot.spocTerm?.displayName.nonEmpty ?? "当前学期")
    } footer: {
      Text("更新于 \(snapshot.fetchedAt.formatted(date: .abbreviated, time: .shortened))")
    }
  }

  private func summaryMetric(_ title: String, value: Int, tint: Color) -> some View {
    HStack(spacing: 8) {
      Text("\(value)")
        .font(.title3.monospacedDigit().weight(.semibold))
        .foregroundStyle(tint)
      Text(title)
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func homeworkRow(_ item: HomeworkItem) -> some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: item.status.symbol)
        .foregroundStyle(item.status.tint)
        .padding(.top, 2)
      VStack(alignment: .leading, spacing: 4) {
        Text(item.title)
          .font(.body.weight(.medium))
          .lineLimit(3)
        Text(item.courseName)
          .font(.caption)
          .foregroundStyle(.secondary)
        if let due = item.dueAt {
          Label(
            due.formatted(date: .abbreviated, time: .shortened),
            systemImage: "clock"
          )
          .font(.caption)
          .foregroundStyle(item.status == .overdue ? Color.orange : Color.secondary)
        }
      }
      Spacer(minLength: 6)
      Text(item.status.title)
        .font(.caption.weight(.medium))
        .foregroundStyle(item.status.tint)
    }
    .padding(.vertical, 3)
  }

  private func filteredItems(_ items: [HomeworkItem]) -> [HomeworkItem] {
    items.filteredHomework(status: statusFilter, source: sourceFilter, query: search)
  }
}

private struct IOSHomeworkDetailView: View {
  let item: HomeworkItem
  @EnvironmentObject private var model: HomeworkViewModel
  @Environment(\.openURL) private var openURL

  private var detail: HomeworkDetail? {
    model.detailItemID == item.id ? model.detail : nil
  }

  private var loading: Bool {
    model.detailItemID == item.id && model.isLoadingDetail
  }

  private var error: String? {
    model.detailItemID == item.id ? model.detailErrorMessage : nil
  }

  private var status: HomeworkStatus {
    detail?.submissionStatus ?? item.status
  }

  var body: some View {
    List {
      Section {
        VStack(alignment: .leading, spacing: 6) {
          Text(item.title)
            .font(.title3.weight(.semibold))
          Text("\(item.courseName) · \(item.source.title)")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
      }

      if loading {
        Section {
          HStack(spacing: 10) {
            ProgressView()
            Text("正在读取作业详情…")
          }
        }
      } else if let error {
        Section {
          IOSInlineMessage(error, systemImage: "exclamationmark.triangle.fill", tint: .orange)
          Button("重试") { Task { await model.loadDetail(for: item) } }
        }
      } else if let detail {
        Section("作业信息") {
          LabeledContent("提交状态", value: status.title)
          if status == .unknown, let value = detail.statusDetail ?? item.statusDetail {
            LabeledContent("上游状态", value: value)
          }
          if let teacher = item.teacherName, teacher.isEmpty == false {
            LabeledContent("教师", value: teacher)
          }
          if let published = detail.publishedAt ?? item.publishedAt {
            LabeledContent("发布时间", value: published.formatted(date: .abbreviated, time: .shortened))
          }
          if let due = detail.dueAt ?? item.dueAt {
            LabeledContent("截止时间", value: due.formatted(date: .abbreviated, time: .shortened))
          }
          if let score = detail.score ?? item.score, score.isEmpty == false {
            LabeledContent("作业分值", value: score)
          }
          if let earned = detail.earnedScore, earned.isEmpty == false {
            LabeledContent("当前得分", value: earned)
          }
          if let total = detail.totalProblems, total > 0 {
            LabeledContent("完成进度", value: "\(detail.submittedCount ?? 0) / \(total) 题")
          }
        }

        Section("作业要求") {
          if let content = detail.content?.trimmingCharacters(in: .whitespacesAndNewlines), content.isEmpty == false {
            Text(content)
              .textSelection(.enabled)
          } else {
            Text("上游暂未返回可显示的文字要求。若作业包含附件或复杂格式，请到原作业页面查看。")
              .foregroundStyle(.secondary)
          }
        }

        if detail.problems.isEmpty == false {
          Section("题目与提交进度") {
            ForEach(detail.problems) { problem in
              HStack(alignment: .top, spacing: 10) {
                Image(systemName: problem.status == .submitted ? "checkmark.circle.fill" : "circle")
                  .foregroundStyle(problem.status == .submitted ? Color.green : Color.secondary)
                  .padding(.top, 2)
                VStack(alignment: .leading, spacing: 3) {
                  Text(problem.name)
                  Text(problem.statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                if let earned = problem.earnedScore, let maximum = problem.maxScore {
                  Text("\(earned) / \(maximum)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                } else if let maximum = problem.maxScore {
                  Text("满分 \(maximum)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                }
              }
            }
          }
        }
      }

      Section {
        if let url = item.sourceURL ?? (item.source == .spoc ? URL(string: "https://spoc.buaa.edu.cn/") : nil) {
          Button {
            openURL(url)
          } label: {
            Label("在 \(item.source.title) 网页端打开", systemImage: "arrow.up.right.square")
          }
        }
      } footer: {
        Text("提交、附件和网页端复杂格式需要在原始网站完成。")
      }
    }
    .listStyle(.insetGrouped)
    .navigationTitle("作业详情")
    .navigationBarTitleDisplayMode(.inline)
    .task(id: item.id) {
      await model.loadDetail(for: item)
    }
    .onDisappear {
      model.clearDetail()
    }
  }
}

private extension String {
  var nonEmpty: String? {
    let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }
}
