import SwiftUI

struct CampusNoticesSummaryView: View {
  @EnvironmentObject private var model: CampusNoticesViewModel

  private let noticesURL = URL(string: "https://news.buaa.edu.cn/tzgg.htm")!

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Label("北航通知公告", systemImage: "bell.badge")
          .font(.title3.weight(.semibold))
        Spacer()
        Link("查看全部", destination: noticesURL)
        Button {
          Task { await model.refresh(force: true) }
        } label: {
          if model.isLoading {
            ProgressView().controlSize(.small)
          } else {
            Image(systemName: "arrow.clockwise")
          }
        }
        .buttonStyle(.borderless)
        .disabled(model.isLoading)
        .accessibilityLabel(model.isLoading ? "正在刷新通知" : "刷新通知")
      }

      if model.isLoading && model.notices.isEmpty {
        ProgressView("正在读取学校通知…")
      } else if model.isLoading {
        StatusNotice(message: "正在更新通知 · 显示上次读取内容", kind: .information)
      } else if let error = model.errorMessage, model.notices.isEmpty {
        StatusNotice(message: "学校通知暂不可用：\(error)", kind: .warning)
      } else if model.notices.isEmpty {
        Text("暂无可显示的通知")
          .foregroundStyle(.secondary)
      } else {
        ForEach(model.notices) { notice in
          Link(destination: notice.url) {
            HStack(alignment: .top, spacing: 12) {
              Text(notice.publishedAt)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 82, alignment: .leading)
              VStack(alignment: .leading, spacing: 4) {
                Text(notice.title)
                  .font(.body.weight(.medium))
                  .multilineTextAlignment(.leading)
                  .lineLimit(2)
                if !notice.summary.isEmpty {
                  Text(notice.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                }
              }
              Spacer(minLength: 0)
              Image(systemName: "arrow.up.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .accessibilityLabel("\(notice.publishedAt)，\(notice.title)")
        }
        if let fetchedAt = model.fetchedAt {
          let label = model.errorMessage != nil ? "上次成功读取" : (model.isUsingCachedData ? "缓存于" : "更新于")
          Text("官网通知 · \(label) \(fetchedAt.formatted(date: .omitted, time: .shortened))")
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
        if let error = model.errorMessage {
          StatusNotice(message: "通知刷新失败，保留上次读取内容：\(error)", kind: .warning)
        }
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.ginkgoCardBackground, in: RoundedRectangle(cornerRadius: 12))
    .task { await model.refresh() }
  }
}
