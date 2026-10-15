import SwiftUI

struct HomeworkView: View {
  @EnvironmentObject private var appState: AppState
  @EnvironmentObject private var model: HomeworkViewModel

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        PageHeading(eyebrow: "ACADEMIC / HOMEWORK", title: "学校作业", subtitle: "汇总学校系统中的课程作业与截止时间")
        if let snapshot = model.snapshot {
          HStack {
            Label("缓存结果", systemImage: "externaldrive")
            Text(snapshot.fetchedAt.formatted(date: .abbreviated, time: .shortened)).foregroundStyle(.secondary)
            Spacer()
            Button { Task { await model.refresh() } } label: { Label("刷新", systemImage: "arrow.clockwise") }
              .disabled(model.isLoading).keyboardShortcut("r", modifiers: .command)
          }.font(.callout)
          if let error = model.errorMessage {
            StatusNotice(message: "作业更新失败：\(error) · 保留截至 \(snapshot.fetchedAt.formatted(date: .abbreviated, time: .shortened)) 的结果", kind: .warning)
          } else if !snapshot.unavailableSources.isEmpty {
            let sources = snapshot.unavailableSources.map(\.title).joined(separator: "、")
            StatusNotice(message: "部分来源暂时不可用（\(sources)），以下结果不完整", kind: .warning)
          } else if model.isLoading {
            StatusNotice(message: "正在核对学校作业…", kind: .information)
          }
          if model.pendingItems.isEmpty && snapshot.unavailableSources.isEmpty && model.errorMessage == nil {
            PageEmptyState(symbol: "checkmark.circle", title: "暂无待处理作业", detail: "当前缓存中没有待完成或已逾期的作业。")
          } else if model.pendingItems.isEmpty {
            PageEmptyState(symbol: "questionmark.folder", title: "暂时无法确认作业状态", detail: "至少一个学校作业来源没有返回结果，请刷新或稍后再试。")
          } else {
            ProgressiveList(items: model.pendingItems, pageSize: 40) { item in
                HStack(alignment: .top, spacing: 12) {
                  Image(systemName: item.status == .overdue ? "exclamationmark.circle.fill" : "doc.text.fill")
                    .foregroundStyle(item.status == .overdue ? .orange : .accentColor)
                  VStack(alignment: .leading, spacing: 4) {
                    Text(item.title).font(.body.weight(.medium))
                    Text(item.courseName).font(.caption).foregroundStyle(.secondary)
                    if let dueAt = item.dueAt { Text("截止：\(dueAt.formatted(date: .abbreviated, time: .shortened))").font(.caption2).foregroundStyle(.secondary) }
                  }
                  Spacer()
                  Text(item.status == .overdue ? "已逾期" : "待处理").font(.caption).foregroundStyle(item.status == .overdue ? .orange : .secondary)
                }.padding(14).background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
            }
          }
        } else if model.isLoading {
          ProgressView("正在查询学校作业…").frame(maxWidth: .infinity, minHeight: 220)
        } else {
          PageEmptyState(symbol: "doc.badge.ellipsis", title: "暂时无法获取学校作业", detail: model.errorMessage ?? "学校服务尚未返回可用结果，请稍后重试。")
          Button("重试") { Task { await model.refresh() } }.buttonStyle(.borderedProminent)
        }
      }.padding(24).frame(maxWidth: 820, alignment: .leading).frame(maxWidth: .infinity)
    }.background(Color(nsColor: .windowBackgroundColor))
      .task(id: appState.user?.schoolid) {
        if let account = appState.user?.schoolid { await model.start(account: account) }
      }
      .onChange(of: model.needsSessionCheck) { _, needed in
        if needed { Task { _ = try? await appState.confirmSessionAfterAuthFailure() } }
      }
  }
}
